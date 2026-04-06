import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';

import 'auth_service.dart';

/// Callback signatures for TrackingService events.
typedef OnConnected = void Function();
typedef OnDisconnected = void Function();
typedef OnPositionUpdate = void Function(Position position);
typedef OnAck = void Function(Map<String, dynamic> ack);
typedef OnTrackingError = void Function(String message);

/// Manages WebSocket connection to `/ws/track` and streams GPS positions.
///
/// Uses `geolocator` for GPS and `web_socket_channel` for WebSocket.
/// Bearer token is sent via Authorization header during WS upgrade.
class TrackingService {
  static const _envBaseUrl = String.fromEnvironment('API_URL');

  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  IOWebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  bool _isStopping = false;
  int _retryCount = 0;
  Timer? _reconnectTimer;
  String? _assignmentId;

  // Callbacks
  OnConnected? onConnected;
  OnDisconnected? onDisconnected;
  OnPositionUpdate? onPositionUpdate;
  OnAck? onAck;
  OnTrackingError? onError;

  bool get isConnected => _isConnected;

  /// Set assignment_id for navigation-linked GPS updates.
  void setAssignmentId(String? id) => _assignmentId = id;

  /// Start GPS tracking: connect WebSocket + stream positions.
  Future<void> start() async {
    _isStopping = false;
    _retryCount = 0;

    // 1. Check & request location permission
    final permission = await _ensureLocationPermission();
    if (!permission) {
      onError?.call('location_permission_denied');
      return;
    }

    // 2. Connect WebSocket
    await _connectWebSocket();

    // 3. Start GPS stream only if WebSocket connected successfully
    if (_isConnected) {
      _startGpsStream();
    }
  }

  /// Stop GPS tracking: close WebSocket + cancel GPS stream.
  Future<void> stop() async {
    _isStopping = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _positionSub?.cancel();
    _positionSub = null;

    await _wsSub?.cancel();
    _wsSub = null;

    await _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;

    _isConnected = false;
    _assignmentId = null;
    onDisconnected?.call();
  }

  // ─── Location Permission ──────────────────────────────────────────────────

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call('location_service_disabled');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call('location_permission_denied_forever');
      return false;
    }

    return true;
  }

  // ─── WebSocket Connection ─────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      onError?.call('no_auth_token');
      return;
    }

    // Cancel any previous WS subscription to avoid orphaned listeners
    await _wsSub?.cancel();
    _wsSub = null;

    // Convert http(s):// → ws(s)://
    final wsUrl = _defaultBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ws/track');

    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        // Let the server handle ping/pong (30s interval, 10s timeout).
        // Don't set client-side pingInterval to avoid conflict.
      );

      // Wait for the connection to be ready
      await _channel!.ready;

      _isConnected = true;
      _retryCount = 0;
      onConnected?.call();

      // Application-level heartbeat: send a lightweight JSON message every 20s.
      // This keeps the connection alive even when GPS is stationary (no updates).
      // The server treats any Text message as activity, resetting its ping timer.
      // This is needed because dart:io WebSocket on iOS may not auto-respond
      // to server-sent Ping frames with Pong at the protocol level.
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'heartbeat'}));
          } catch (_) {}
        }
      });

      // Listen for server messages (acks / errors).
      // Note: Ping/Pong frames are handled automatically at the dart:io
      // WebSocket layer and never appear in the stream — only Text/Binary
      // data frames reach this listener.
      _wsSub = _channel!.stream.listen(
        (data) {
          if (data is! String) return; // Skip non-text frames
          try {
            final msg = jsonDecode(data) as Map<String, dynamic>;
            if (msg.containsKey('error')) {
              onError?.call(msg['error'] as String);
            } else {
              onAck?.call(msg);
            }
          } catch (_) {
            // Ignore malformed messages
          }
        },
        onError: (error) {
          _isConnected = false;
          onDisconnected?.call();
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          onDisconnected?.call();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      onError?.call('ws_connect_failed');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isStopping || _retryCount >= 5) return;

    _retryCount++;
    final delay = Duration(seconds: _retryCount * 2); // 2, 4, 6, 8, 10s

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_isStopping) {
        await _connectWebSocket();
        // Restart GPS stream after successful reconnect
        if (_isConnected) {
          _startGpsStream();
        }
      }
    });
  }

  // ─── GPS Streaming ────────────────────────────────────────────────────────

  void _startGpsStream() {
    _positionSub?.cancel();

    // Send initial position immediately (don't wait for distanceFilter delta)
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).then((position) {
      onPositionUpdate?.call(position);
      _sendGpsUpdate(position);
    }).catchError((e) {
      // Log error but continue — the position stream below will still work
      // when the device eventually gets a GPS fix
      // ignore: avoid_print
      print('[TrackingService] getCurrentPosition failed: $e — waiting for stream');
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters — only send when moved ≥10m
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        onPositionUpdate?.call(position);
        _sendGpsUpdate(position);
      },
      onError: (error) {
        onError?.call('gps_stream_error');
      },
    );
  }

  void _sendGpsUpdate(Position position) {
    if (!_isConnected || _channel == null) return;

    final update = {
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'assignment_id': _assignmentId,
    };

    try {
      _channel!.sink.add(jsonEncode(update));
    } catch (_) {
      // WebSocket send failed — will reconnect via onDone/onError
    }
  }
}
