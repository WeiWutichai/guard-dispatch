import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Register the device's FCM token with the backend so push notifications
  /// can be delivered. Should be called once after successful login.
  /// The backend stores the token in `notification.fcm_tokens`.
  Future<void> registerFcmToken() async {
    try {
      // Request permission (iOS requires explicit, Android auto-grants)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) debugPrint('[FCM] Permission denied by user');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('[FCM] Token is null');
        return;
      }

      if (kDebugMode) debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');

      // POST /notification/tokens
      await _apiClient.dio.post(
        '/notification/tokens',
        data: {'token': token, 'device_type': Platform.isIOS ? 'ios' : 'android'},
      );

      if (kDebugMode) debugPrint('[FCM] Token registered with backend');

      // Listen for token refreshes (e.g. app reinstall, user clears data)
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _apiClient.dio.post(
            '/notification/tokens',
            data: {'token': newToken, 'device_type': Platform.isIOS ? 'ios' : 'android'},
          );
          if (kDebugMode) debugPrint('[FCM] Refreshed token registered');
        } catch (e) {
          if (kDebugMode) debugPrint('[FCM] Failed to register refreshed token: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] registerFcmToken error: $e');
    }
  }

  /// Unregister the current FCM token (called on logout).
  Future<void> unregisterFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _apiClient.dio.delete(
          '/notification/tokens',
          data: {'token': token},
        );
        if (kDebugMode) debugPrint('[FCM] Token unregistered');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] unregisterFcmToken error: $e');
    }
  }

  /// GET /notification/notifications?unread_only=...&limit=...&offset=...&role=...
  Future<List<Map<String, dynamic>>> listNotifications({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
    String? role,
  }) async {
    final params = <String, dynamic>{
      'unread_only': unreadOnly,
      'limit': limit,
      'offset': offset,
    };
    if (role != null) params['role'] = role;
    final response = await _apiClient.dio.get(
      '/notification/notifications',
      queryParameters: params,
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /notification/notifications/unread-count?role=...
  Future<int> getUnreadCount({String? role}) async {
    final params = <String, dynamic>{};
    if (role != null) params['role'] = role;
    final response = await _apiClient.dio.get(
      '/notification/notifications/unread-count',
      queryParameters: params,
    );
    final data = response.data['data'];
    if (data is Map) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// PUT /notification/notifications/{id}/read
  Future<void> markAsRead(String notificationId) async {
    await _apiClient.dio.put(
      '/notification/notifications/$notificationId/read',
    );
  }

  /// PUT /notification/notifications/read-all?role=...
  Future<void> markAllAsRead({String? role}) async {
    final params = <String, dynamic>{};
    if (role != null) params['role'] = role;
    await _apiClient.dio.put(
      '/notification/notifications/read-all',
      queryParameters: params,
    );
  }
}
