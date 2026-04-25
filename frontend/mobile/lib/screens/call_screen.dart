import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../theme/colors.dart';

/// Full-screen WebRTC audio (and optional video) call.
///
/// Two entry modes:
///   - outgoing: construct with `calleeId` — screen initiates the call on open.
///   - incoming: construct with `incomingCallId` — callee has already tapped
///     "Accept"; screen just wires up the peer and waits for the caller's
///     offer to arrive.
class CallScreen extends StatefulWidget {
  final String userName;
  final String? calleeId;
  final String? incomingCallId;
  final String callType; // "audio" | "video"
  final String? assignmentId;
  final String? conversationId;

  const CallScreen({
    super.key,
    required this.userName,
    this.calleeId,
    this.incomingCallId,
    this.callType = 'audio',
    this.assignmentId,
    this.conversationId,
  }) : assert(calleeId != null || incomingCallId != null,
            'Must provide calleeId (outgoing) or incomingCallId (incoming)');

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallService _call;
  String _state = 'connecting'; // connecting | ringing | connected | ended
  bool _muted = false;
  bool _speakerOn = true;
  bool _videoOn = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _errorMessage;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _videoOn = widget.callType == 'video';
    _call = CallService(ApiClient())
      ..onConnected = _handleConnected
      ..onEnded = _handleEnded
      ..onError = _handleError
      ..onRemoteStream = _handleRemoteStream;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!await CallService.requestPermissions(video: _videoOn)) {
      setState(() {
        _state = 'ended';
        _errorMessage = 'กรุณาอนุญาตไมโครโฟน (และกล้อง) ในตั้งค่า';
      });
      return;
    }

    await _remoteRenderer.initialize();
    await _localRenderer.initialize();

    // Defensive: in release mode `assert` is stripped, so we must check
    // the inputs ourselves before dereferencing.
    if (widget.incomingCallId == null && (widget.calleeId == null || widget.calleeId!.isEmpty)) {
      setState(() {
        _state = 'ended';
        _errorMessage = 'ไม่พบผู้รับสาย';
      });
      return;
    }

    try {
      if (widget.incomingCallId != null) {
        await _call.accept(
          callId: widget.incomingCallId!,
          callType: widget.callType,
        );
      } else {
        await _call.initiate(
          calleeId: widget.calleeId!,
          callType: widget.callType,
          assignmentId: widget.assignmentId,
          conversationId: widget.conversationId,
        );
      }
      if (mounted) setState(() => _state = 'ringing');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = 'ended';
        _errorMessage = 'เริ่มสายไม่สำเร็จ: ${_formatErr(e)}';
      });
    }
  }

  /// Surface the backend's actual `error.message` instead of Dio's
  /// generic toString. Falls back to the HTTP code, then the raw exception.
  String _formatErr(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (data['message'] is String) return data['message'] as String;
      }
      final s = e.response?.statusCode;
      if (s != null) return 'HTTP $s';
      return 'เครือข่ายขัดข้อง';
    }
    return e.toString();
  }

  void _handleConnected() {
    if (!mounted) return;
    setState(() => _state = 'connected');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _duration += const Duration(seconds: 1));
    });
  }

  void _handleEnded() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _state = 'ended');
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _handleError(String err) {
    if (!mounted) return;
    setState(() {
      _state = 'ended';
      _errorMessage = err;
    });
  }

  void _handleRemoteStream(MediaStream stream) {
    if (!mounted) return;
    setState(() {
      _remoteRenderer.srcObject = stream;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    _call.end(reason: 'hangup_self');
    super.dispose();
  }

  // ─── Controls ────────────────────────────────────────────────────────────
  void _toggleMute() {
    final next = !_muted;
    _call.setMuted(next);
    setState(() => _muted = next);
  }

  void _toggleSpeaker() {
    final next = !_speakerOn;
    setState(() => _speakerOn = next);
    Helper.setSpeakerphoneOn(next);
  }

  Future<void> _hangUp() async {
    await _call.end(reason: 'hangup_self');
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showVideo = _videoOn && _remoteRenderer.srcObject != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              if (showVideo)
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: RTCVideoView(_remoteRenderer)),
                      Positioned(
                        top: 16,
                        right: 16,
                        width: 110,
                        height: 150,
                        child: RTCVideoView(_localRenderer, mirror: true),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: const Icon(Icons.person,
                            size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.userName,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stateLabel(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallAction(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'เสียงปิด' : 'เสียงเปิด',
                    active: !_muted,
                    onTap: _toggleMute,
                  ),
                  _CallAction(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: 'ลำโพง',
                    active: _speakerOn,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _hangUp,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  String _stateLabel() {
    switch (_state) {
      case 'connecting':
        return 'กำลังเชื่อมต่อ...';
      case 'ringing':
        return 'กำลังโทร...';
      case 'connected':
        return _formatDuration(_duration);
      case 'ended':
        return _errorMessage ?? 'วางสาย';
      default:
        return '';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CallAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
