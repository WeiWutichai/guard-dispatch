import '../services/api_client.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// GET /notification/notifications?unread_only=...&limit=...&offset=...
  Future<List<Map<String, dynamic>>> listNotifications({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/notification/notifications',
      queryParameters: {
        'unread_only': unreadOnly,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /notification/notifications/unread-count
  Future<int> getUnreadCount() async {
    final response = await _apiClient.dio.get(
      '/notification/notifications/unread-count',
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

  /// PUT /notification/notifications/read-all
  Future<void> markAllAsRead() async {
    await _apiClient.dio.put('/notification/notifications/read-all');
  }
}
