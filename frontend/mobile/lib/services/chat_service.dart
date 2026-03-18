import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';

import 'api_client.dart';
import 'auth_service.dart';

class ChatService {
  final ApiClient _apiClient;

  // WebSocket state
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  bool _isConnected = false;

  ChatService(this._apiClient);

  bool get isWsConnected => _isConnected;

  // ===========================================================================
  // REST: Conversations
  // ===========================================================================

  /// GET /chat/conversations?role=guard|customer
  Future<List<Map<String, dynamic>>> getConversations({String? role}) async {
    final response = await _apiClient.dio.get(
      '/chat/conversations',
      queryParameters: {if (role != null) 'role': role},
    );
    final list = response.data['data'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// POST /chat/conversations
  Future<Map<String, dynamic>> createConversation(
    String requestId,
    List<String> participantIds,
  ) async {
    final response = await _apiClient.dio.post('/chat/conversations', data: {
      'request_id': requestId,
      'participant_ids': participantIds,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Find existing conversation for a request_id, or create a new one.
  Future<String> getOrCreateConversation(
    String requestId,
    String myUserId,
    String otherUserId,
  ) async {
    // Check existing conversations
    final conversations = await getConversations();
    for (final conv in conversations) {
      if (conv['request_id'] == requestId) {
        return conv['id'] as String;
      }
    }

    // Create new conversation
    final created = await createConversation(requestId, [myUserId, otherUserId]);
    return created['id'] as String;
  }

  // ===========================================================================
  // REST: Messages
  // ===========================================================================

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

  // ===========================================================================
  // WebSocket: Real-time chat
  // ===========================================================================

  static const _envBaseUrl = String.fromEnvironment('API_URL');

  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  /// Connect to /ws/chat for real-time messaging.
  /// [onMessage] is called with each incoming OutgoingChatMessage from server.
  Future<void> connectChat(void Function(Map<String, dynamic>) onMessage) async {
    final token = await AuthService.getAccessToken();
    if (token == null) return;

    // Clean up any previous connection
    await _wsSub?.cancel();
    _wsSub = null;

    final wsUrl = _defaultBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ws/chat');

    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: const Duration(seconds: 30),
      );

      await _channel!.ready;
      _isConnected = true;

      _wsSub = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (!msg.containsKey('error')) {
              onMessage(msg);
            }
          } catch (_) {}
        },
        onError: (_) {
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
        },
      );
    } catch (_) {
      _isConnected = false;
    }
  }

  /// Send a text message via the WebSocket connection.
  void sendChatMessage(String conversationId, String content, {String? senderRole}) {
    if (!_isConnected || _channel == null) return;

    final payload = jsonEncode({
      'conversation_id': conversationId,
      'content': content,
      'message_type': 'text',
      if (senderRole != null) 'sender_role': senderRole,
    });

    try {
      _channel!.sink.add(payload);
    } catch (_) {}
  }

  // ===========================================================================
  // REST: Attachments (image/video upload)
  // ===========================================================================

  /// POST /chat/attachments — upload image or video file
  Future<Map<String, dynamic>> uploadAttachment(
    String conversationId,
    File file,
    String mimeType,
  ) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'conversation_id': conversationId,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _apiClient.dio.post(
      '/chat/attachments',
      data: formData,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// GET /chat/attachments/{id} — get fresh signed URL
  Future<Map<String, dynamic>> getAttachmentUrl(String attachmentId) async {
    final response = await _apiClient.dio.get('/chat/attachments/$attachmentId');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// PUT /chat/conversations/{id}/read?role=...
  Future<void> markRead(String conversationId, {String? role}) async {
    await _apiClient.dio.put(
      '/chat/conversations/$conversationId/read',
      queryParameters: {if (role != null) 'role': role},
    );
  }

  /// Disconnect the chat WebSocket.
  Future<void> disconnectChat() async {
    await _wsSub?.cancel();
    _wsSub = null;

    await _channel?.sink.close(WebSocketStatus.normalClosure);
    _channel = null;
    _isConnected = false;
  }
}
