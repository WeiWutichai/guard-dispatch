import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Manages the WebRTC peer connection + signalling WebSocket for a single
/// in-app call. Lifecycle mirrors the backend:
///   initiate → ringing → accepted → connected → ended
///
/// The signalling protocol on `/booking/ws/call` is:
///   - client connects, sends `<call_id>` as the first text frame
///   - server acks with `{"type":"subscribed"}`
///   - both peers exchange `{"type":"offer|answer|candidate","data":...}`
///     JSON frames. Server stamps `sender_id` automatically.
///   - any `{"type":"status","status":"ended|rejected"}` from the server
///     means the other side hung up.
///
/// Caller runs `initiate()` → awaits `onConnected` → `end(reason)`.
/// Callee runs `accept(callId)` → awaits `onConnected` → `end(reason)`.
class CallService {
  final ApiClient _apiClient;

  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  IOWebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;

  String? _callId;
  bool _isCaller = false;
  bool _ended = false;

  /// Remote audio/video stream — set as soon as the peer's first track arrives.
  MediaStream? remoteStream;

  // ─── Public event hooks the UI subscribes to ─────────────────────────────
  VoidCallback? onConnected;
  VoidCallback? onEnded;
  void Function(String error)? onError;
  void Function(MediaStream remote)? onRemoteStream;

  CallService(this._apiClient);

  String? get callId => _callId;

  // ─── Permissions ─────────────────────────────────────────────────────────
  static Future<bool> requestPermissions({bool video = false}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  // ─── Outbound: caller starts a call ──────────────────────────────────────
  Future<Map<String, dynamic>> initiate({
    required String calleeId,
    String callType = 'audio',
    String? assignmentId,
    String? conversationId,
  }) async {
    final resp = await _apiClient.dio.post(
      '/booking/calls/initiate',
      data: {
        'callee_id': calleeId,
        'call_type': callType,
        if (assignmentId != null) 'assignment_id': assignmentId,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );
    final call = (resp.data['data'] as Map).cast<String, dynamic>();
    _callId = call['id'] as String;
    _isCaller = true;

    final iceServers =
        (call['ice_servers'] as List?)?.cast<Map>() ?? _defaultIceServers();

    await _startPeer(iceServers, callType: callType);
    await _connectSignalling();

    // Caller creates the SDP offer right away; it will be delivered to the
    // callee when they subscribe.
    final peer = _peer;
    if (peer == null) {
      throw Exception('peer connection สูญหายหลัง _startPeer');
    }
    try {
      final offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      _sendSignal({
        'type': 'offer',
        'data': {'sdp': offer.sdp, 'type': offer.type},
      });
    } catch (e) {
      throw Exception('สร้าง SDP offer ล้มเหลว: $e');
    }

    return call;
  }

  // ─── Inbound: callee accepts an incoming call ────────────────────────────
  Future<Map<String, dynamic>> accept({
    required String callId,
    String callType = 'audio',
  }) async {
    _callId = callId;
    _isCaller = false;

    final resp = await _apiClient.dio.put('/booking/calls/$callId/accept');
    final call = (resp.data['data'] as Map).cast<String, dynamic>();

    final iceServers =
        (call['ice_servers'] as List?)?.cast<Map>() ?? _defaultIceServers();

    await _startPeer(iceServers, callType: callType);
    await _connectSignalling();
    // Don't send offer — caller's already sitting in the channel. The signal
    // handler will pick up the offer when it arrives on the subscribe ack.
    return call;
  }

  Future<void> reject(String callId) async {
    try {
      await _apiClient.dio.put('/booking/calls/$callId/reject');
    } catch (_) {}
  }

  /// Enable or disable the outbound microphone track. Called from the UI
  /// when the user toggles mute.
  void setMuted(bool muted) {
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
  }

  /// Enable or disable the outbound video track (video calls only).
  void setVideoEnabled(bool enabled) {
    for (final track in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> end({required String reason}) async {
    if (_ended) return;
    _ended = true;
    final id = _callId;
    if (id != null) {
      try {
        await _apiClient.dio.put(
          '/booking/calls/$id/end',
          data: {'reason': reason},
        );
      } catch (_) {}
    }
    await _cleanup();
    onEnded?.call();
  }

  // ─── WebRTC plumbing ─────────────────────────────────────────────────────
  Future<void> _startPeer(List<Map> iceServers, {required String callType}) async {
    final config = {
      'iceServers': iceServers
          .map((s) => {
                'urls': (s['urls'] as List?)?.cast<String>() ?? const [],
                if (s['username'] != null) 'username': s['username'],
                if (s['credential'] != null) 'credential': s['credential'],
              })
          .toList(),
      'sdpSemantics': 'unified-plan',
    };

    // Use local refs everywhere instead of `_peer!` / `_localStream!`. The
    // `!` operator made every step a potential "Null check operator used on
    // a null value" with no clue WHICH step failed. With named locals we
    // throw an explicit Exception that surfaces in the user-visible error.
    final RTCPeerConnection peer;
    try {
      peer = await createPeerConnection(config, {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      });
    } catch (e) {
      throw Exception('สร้าง WebRTC peer connection ล้มเหลว: $e');
    }
    _peer = peer;

    peer.onIceCandidate = (RTCIceCandidate c) {
      _sendSignal({
        'type': 'candidate',
        'data': {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      });
    };

    peer.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        remoteStream = stream;
        onRemoteStream?.call(stream);
      }
    };

    peer.onConnectionState = (RTCPeerConnectionState state) async {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        final id = _callId;
        if (id != null) {
          // Fire-and-forget mark-connected so duration timing starts from
          // the true media handshake.
          try {
            await _apiClient.dio.put('/booking/calls/$id/connected');
          } catch (_) {}
        }
        onConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onError?.call('peer_${state.name}');
      }
    };

    // Grab local audio (and video if requested) and attach it to the peer.
    final constraints = <String, dynamic>{
      'audio': true,
      'video': callType == 'video'
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    final MediaStream stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      throw Exception('ขอสิทธิ์ใช้ไมโครโฟน/กล้องไม่สำเร็จ: $e');
    }
    _localStream = stream;
    final tracks = stream.getTracks();
    if (tracks.isEmpty) {
      throw Exception('ไม่พบไมโครโฟนหรือกล้องบนเครื่อง');
    }
    for (final track in tracks) {
      await peer.addTrack(track, stream);
    }
  }

  Future<void> _connectSignalling() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('ไม่พบ access token — ล็อกอินใหม่');
    }

    final callId = _callId;
    if (callId == null || callId.isEmpty) {
      throw Exception('call id ว่างก่อน connect signalling');
    }

    final base = ApiClient.baseUrl;
    final wsUrl = base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');

    final IOWebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(
        Uri.parse('$wsUrl/booking/ws/call'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      throw Exception('เปิด WebSocket signalling ล้มเหลว: $e');
    }
    _ws = channel;

    // First frame is the call_id (bare UUID, server handles both formats).
    channel.sink.add(callId);

    _wsSub = channel.stream.listen(
      (raw) => _handleSignal(raw),
      onDone: () {
        if (!_ended) onError?.call('signalling_closed');
      },
      onError: (e) {
        if (kDebugMode) debugPrint('[call] ws error: $e');
        onError?.call('signalling_error');
      },
    );
  }

  void _sendSignal(Map<String, dynamic> msg) {
    final ws = _ws;
    if (ws == null) return;
    try {
      ws.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  Future<void> _handleSignal(dynamic raw) async {
    if (raw is! String) return;
    final Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      msg = decoded.cast<String, dynamic>();
    } catch (_) {
      return;
    }

    final type = msg['type'] as String?;
    if (type == null) return;

    if (type == 'status') {
      final status = msg['status'] as String?;
      if (status == 'ended' || status == 'rejected') {
        await _cleanup();
        onEnded?.call();
      }
      return;
    }

    if (type == 'subscribed') return;

    final data = (msg['data'] as Map?)?.cast<String, dynamic>();
    if (data == null) return;

    final peer = _peer;
    if (peer == null) return;

    switch (type) {
      case 'offer':
        {
          if (_isCaller) return; // shouldn't happen — caller made the offer
          final desc = RTCSessionDescription(
            data['sdp'] as String?,
            data['type'] as String? ?? 'offer',
          );
          await peer.setRemoteDescription(desc);
          final answer = await peer.createAnswer();
          await peer.setLocalDescription(answer);
          _sendSignal({
            'type': 'answer',
            'data': {'sdp': answer.sdp, 'type': answer.type},
          });
          break;
        }
      case 'answer':
        {
          if (!_isCaller) return;
          final desc = RTCSessionDescription(
            data['sdp'] as String?,
            data['type'] as String? ?? 'answer',
          );
          await peer.setRemoteDescription(desc);
          break;
        }
      case 'candidate':
        {
          final cand = RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            (data['sdpMLineIndex'] as num?)?.toInt(),
          );
          await peer.addCandidate(cand);
          break;
        }
    }
  }

  Future<void> _cleanup() async {
    try {
      await _wsSub?.cancel();
    } catch (_) {}
    _wsSub = null;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;

    try {
      for (final track in _localStream?.getTracks() ?? []) {
        await track.stop();
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await _peer?.close();
    } catch (_) {}
    _peer = null;
    remoteStream = null;
  }

  List<Map> _defaultIceServers() {
    return [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      }
    ];
  }

  // ignore: unused_element
  static String _platformName() =>
      Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other';
}
