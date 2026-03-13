import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  NotificationProvider(this._service);

  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => _notifications;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Fetch notifications list from API.
  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _notifications =
          await _service.listNotifications(unreadOnly: unreadOnly);
      // Update unread count from the fetched data
      _unreadCount =
          _notifications.where((n) => n['is_read'] != true).length;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch unread count (lightweight — for badge display).
  Future<void> fetchUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationProvider] fetchUnreadCount error: $e');
    }
  }

  /// Mark single notification as read (optimistic local update).
  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      final idx =
          _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx != -1) {
        _notifications[idx] = {
          ..._notifications[idx],
          'is_read': true,
        };
      }
      _unreadCount = (_unreadCount - 1).clamp(0, 999999);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = {..._notifications[i], 'is_read': true};
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
