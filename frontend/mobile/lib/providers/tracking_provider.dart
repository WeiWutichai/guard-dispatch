import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/tracking_service.dart';

/// State management for GPS tracking.
///
/// Guards toggle "Go Online" → starts GPS + WebSocket streaming.
/// Admin dashboard map shows guard positions in real-time.
class TrackingProvider extends ChangeNotifier {
  final TrackingService _service;

  bool _isOnline = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  Position? _lastPosition;
  bool _serverConfirmed = false;
  String? _error;

  TrackingProvider(this._service) {
    _service
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onPositionUpdate = _handlePositionUpdate
      ..onAck = _handleAck
      ..onError = _handleError;
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isOnline => _isOnline;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  Position? get lastPosition => _lastPosition;
  String? get error => _error;

  /// True when server has confirmed receiving at least one GPS update.
  /// This matches admin map logic: both green only when backend has
  /// a fresh recorded_at from upsert_location().
  ///
  /// Lifecycle:
  /// - toggle on → false (gray)
  /// - GPS sent → server ACK {"status":"ok"} → true (green)
  /// - WS disconnects → false (gray)
  /// - toggle off → false (gray)
  bool get hasRecentGps => _isConnected && _serverConfirmed;

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> goOnline() async {
    if (_isOnline || _isConnecting) return;

    _isConnecting = true;
    _error = null;
    notifyListeners();

    await _service.start();

    // If service reported an error immediately (e.g. permission denied),
    // _error will be set and _isConnected will be false.
    if (_error != null) {
      _isConnecting = false;
      _isOnline = false;
      notifyListeners();
      return;
    }

    _isOnline = true;
    _isConnecting = false;
    notifyListeners();
  }

  Future<void> goOffline() async {
    if (!_isOnline && !_isConnecting) return;

    await _service.stop();

    _isOnline = false;
    _isConnecting = false;
    _isConnected = false;
    _lastPosition = null;
    _serverConfirmed = false;
    _error = null;
    notifyListeners();
  }

  /// Start navigation tracking with an assignment_id.
  /// Sets the assignment_id on GPS updates and goes online if needed.
  Future<void> startNavigationTracking(String assignmentId) async {
    _service.setAssignmentId(assignmentId);
    if (!_isOnline) {
      await goOnline();
    }
  }

  /// Clear assignment tracking (back to general GPS).
  void clearAssignment() {
    _service.setAssignmentId(null);
  }

  Future<void> toggle() async {
    if (_isOnline) {
      await goOffline();
    } else {
      await goOnline();
    }
  }

  // ─── Callbacks from TrackingService ───────────────────────────────────────

  void _handleConnected() {
    _isConnected = true;
    _isConnecting = false;
    _error = null;
    notifyListeners();
  }

  void _handleDisconnected() {
    _isConnected = false;
    _serverConfirmed = false;
    notifyListeners();
  }

  void _handlePositionUpdate(Position position) {
    _lastPosition = position;
    notifyListeners();
  }

  void _handleAck(Map<String, dynamic> ack) {
    // Only trust ACKs that include recorded_at (proves a real GPS upsert happened)
    if (ack['status'] == 'ok' && ack['recorded_at'] != null && !_serverConfirmed) {
      _serverConfirmed = true;
      notifyListeners();
    }
  }

  void _handleError(String message) {
    _error = message;
    // On permission errors, go offline automatically
    if (message.contains('permission') || message == 'no_auth_token') {
      _isOnline = false;
      _isConnecting = false;
      _isConnected = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }
}
