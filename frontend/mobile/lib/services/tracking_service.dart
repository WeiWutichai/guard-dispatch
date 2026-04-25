import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
  Timer? _positionRefreshTimer;
  Position? _lastKnownPosition;
  bool _isConnected = false;
  bool _isStopping = false;
  int _retryCount = 0;
  int _freshFailCount = 0;
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
    _positionRefreshTimer?.cancel();
    _positionRefreshTimer = null;

    await _positionSub?.cancel();
    _positionSub = null;

    await _wsSub?.cancel();
    _wsSub = null;

    await _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;

    _isConnected = false;
    _assignmentId = null;
    _lastKnownPosition = null;
    _freshFailCount = 0;
    _retryCount = 0;
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
    }

    // B4 — require `always` so the guard keeps streaming GPS when the screen
    // locks or another app takes focus. If the OS only grants `whileInUse`
    // we try to escalate once; if the user still declines we surface a
    // distinct error code so the UI can route them to system settings.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      // Some devices (notably Android 11+) require a return trip to Settings
      // to upgrade "While using" → "Always". Geolocator reports the current
      // state after the request; if it's still not `always`, bail out.
    }

    if (permission == LocationPermission.always) {
      return true;
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call('location_permission_denied_forever');
    } else if (permission == LocationPermission.whileInUse) {
      // Got "while in use" but not "always" — treat as rejection so the
      // dashboard can prompt for upgrade to Always.
      onError?.call('location_permission_needs_always');
    } else {
      onError?.call('location_permission_denied');
    }
    return false;
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
      // Token may have expired during reconnect — try refreshing once
      // before falling back to scheduled reconnect.
      final refreshed = await _tryRefreshToken();
      if (refreshed && !_isStopping) {
        _scheduleReconnect();
      } else {
        onError?.call('ws_connect_failed');
        _scheduleReconnect();
      }
    }
  }

  /// Attempt to refresh the access token via /auth/refresh/mobile.
  /// Returns true if a new token was successfully stored.
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final dio = Dio(BaseOptions(
        baseUrl: _defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.post(
        '/auth/refresh/mobile',
        data: {'refresh_token': refreshToken},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null && newRefresh != null) {
          await AuthService.storeTokens(newAccess, newRefresh);
          return true;
        }
      }
    } catch (_) {
      // Refresh failed — fall through to scheduled reconnect
    }
    return false;
  }

  void _scheduleReconnect() {
    if (_isStopping) return;

    _retryCount++;
    // Exponential backoff capped at 60s: 2, 4, 8, 16, 32, 60, 60, ...
    // Unbounded attempts — user must toggle off to stop retries.
    final shift = _retryCount.clamp(1, 6);
    final seconds = (1 << shift).clamp(2, 60);
    final delay = Duration(seconds: seconds);

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
    _positionRefreshTimer?.cancel();
    _freshFailCount = 0;

    // 1. Send cached OS position instantly (no GPS hardware delay).
    //    This ensures the guard appears on the map immediately, even indoors.
    _sendCachedPosition();

    // 2. Then get a fresh high-accuracy fix (may take a few seconds).
    _sendFreshPosition();

    // 3. Periodic refresh every 30s for stationary guards.
    //    Re-sends cached _lastKnownPosition so backend refreshes recorded_at
    //    and the guard doesn't fall off the available-guards freshness window.
    //    If no fix is ever obtained, surface a clear 'gps_unavailable' error
    //    so UI can tell the user GPS is stuck (WS is up but nothing to send).
    _positionRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastKnownPosition != null) {
        _freshFailCount = 0;
        _sendGpsUpdate(_lastKnownPosition!);
      } else {
        _freshFailCount++;
        _sendFreshPosition();
        // ~90s without any fix → notify once (don't spam)
        if (_freshFailCount == 3) {
          onError?.call('gps_unavailable');
        }
      }
    });

    // 4. Stream movement-based updates (distanceFilter ≥ 10m).
    //
    // Platform-specific config so the GPS stream survives screen lock /
    // app backgrounding:
    //
    //   Android — must declare a foreground service with a persistent
    //   notification or Doze kills the stream within ~30s. The
    //   `foregroundNotificationConfig` field auto-promotes the location
    //   plugin to foreground, hooking ACCESS_BACKGROUND_LOCATION +
    //   FOREGROUND_SERVICE_LOCATION (declared in AndroidManifest.xml).
    //
    //   iOS — must opt in to background updates explicitly via
    //   `allowsBackgroundLocationUpdates`, AND the app must declare
    //   `UIBackgroundModes: [location]` in Info.plist (already done).
    //   `pauseLocationUpdatesAutomatically: false` keeps the stream open
    //   when the OS thinks the user is "stopped".
    final locationSettings = _backgroundLocationSettings();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        _lastKnownPosition = position;
        onPositionUpdate?.call(position);
        _sendGpsUpdate(position);
      },
      onError: (error) {
        onError?.call('gps_stream_error');
      },
    );
  }

  /// Send the OS-cached last known position instantly (no GPS hardware needed).
  void _sendCachedPosition() {
    Geolocator.getLastKnownPosition().then((position) {
      if (position != null && _lastKnownPosition == null) {
        _lastKnownPosition = position;
        onPositionUpdate?.call(position);
        _sendGpsUpdate(position);
      }
    }).catchError((e) {
      // ignore: avoid_print
      print('[TrackingService] getLastKnownPosition failed: $e');
    });
  }

  /// Get a fresh high-accuracy GPS fix (may take seconds for cold start).
  void _sendFreshPosition() {
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).then((position) {
      _lastKnownPosition = position;
      _freshFailCount = 0;
      onPositionUpdate?.call(position);
      _sendGpsUpdate(position);
    }).catchError((e) {
      // ignore: avoid_print
      print('[TrackingService] getCurrentPosition failed: $e — waiting for stream');
    });
  }

  void _sendGpsUpdate(Position position) {
    if (!_isConnected || _channel == null) return;

    // iOS CLLocation returns -1 for invalid course/speed; Android may return 0
    // or NaN. Backend validates heading ∈ [0,360], speed ∈ [0,500], accuracy
    // ∈ [0,10000] — any out-of-range value gets the entire update rejected,
    // which prevents recorded_at/is_online from being refreshed on admin map.
    // Send null for invalid readings so backend skips range checks.
    double? sanitize(double value, double max) {
      if (value.isNaN || value.isInfinite || value < 0 || value > max) {
        return null;
      }
      return value;
    }

    final update = {
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': sanitize(position.accuracy, 10000),
      'heading': sanitize(position.heading, 360),
      'speed': sanitize(position.speed, 500),
      'assignment_id': _assignmentId,
    };

    try {
      _channel!.sink.add(jsonEncode(update));
    } catch (_) {
      // WebSocket send failed — will reconnect via onDone/onError
    }
  }

  /// Build the platform-specific `LocationSettings` used by the position
  /// stream. Android needs a foreground notification (Doze kills location
  /// otherwise); iOS needs explicit background-update opt-in.
  LocationSettings _backgroundLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        // Mute Android battery optimizer's "stop in 30s" rule by promoting
        // the location plugin to a foreground service. The notification is
        // visible — that's the OS contract for background GPS.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'P-Guard ออนไลน์',
          notificationText: 'กำลังส่งตำแหน่งให้ลูกค้าเรียลไทม์',
          enableWakeLock: true,
          notificationIcon: AndroidResource(name: 'ic_launcher'),
        ),
      );
    }
    if (Platform.isIOS) {
      // iOS: background location is enabled by `UIBackgroundModes: [location]`
      // in Info.plist (declared in B4). The `pauseLocationUpdatesAutomatically:
      // false` flag plus `showBackgroundLocationIndicator: true` keeps the
      // stream live when the screen locks and shows the standard blue bar.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
}
