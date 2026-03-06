import '../services/api_client.dart';

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  /// GET /chat/conversations
  Future<List<Map<String, dynamic>>> getConversations() async {
    final response = await _apiClient.dio.get('/chat/conversations');
    final list = response.data['data'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// GET /chat/conversations/{id}/messages
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = response.data['data'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
