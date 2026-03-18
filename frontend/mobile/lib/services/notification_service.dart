import '../services/api_client.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

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
