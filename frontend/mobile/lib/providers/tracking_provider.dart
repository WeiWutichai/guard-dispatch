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
  String? _error;

  TrackingProvider(this._service) {
    _service
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onPositionUpdate = _handlePositionUpdate
      ..onError = _handleError;
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isOnline => _isOnline;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  Position? get lastPosition => _lastPosition;
  String? get error => _error;

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
    _error = null;
    notifyListeners();
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
    notifyListeners();
  }

  void _handlePositionUpdate(Position position) {
    _lastPosition = position;
    notifyListeners();
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
