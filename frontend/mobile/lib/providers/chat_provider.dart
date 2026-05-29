import 'dart:io';

import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service;

  ChatProvider(this._service);

  // ===========================================================================
  // Conversations list state
  // ===========================================================================

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> get conversations => _conversations;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchConversations({String? role}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await _service.getConversations(role: role);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ===========================================================================
  // Active conversation messages state
  // ===========================================================================

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> get messages => _messages;

  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  bool _isLoadingMessages = false;
  bool get isLoadingMessages => _isLoadingMessages;

  /// Fetch message history for a conversation (newest-first from API → reversed to oldest-first).
  Future<void> fetchMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();
    try {
      final result = await _service.getMessages(conversationId);
      // API returns newest first — reverse for chronological display
      _messages = result.reversed.toList();
    } catch (e) {
      debugPrint('[ChatProvider] fetchMessages error: $e');
      _messages = [];
    }
    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Connect WebSocket and start receiving messages for the given conversation.
  Future<void> connectToConversation(String conversationId) async {
    _activeConversationId = conversationId;

    await _service.connectChat((msg) {
      // Only add messages for the active conversation
      final msgConvId = msg['conversation_id'] as String?;
      if (msgConvId == _activeConversationId) {
        // Avoid duplicate if message already exists (from optimistic send or history)
        final msgId = msg['id'] as String?;
        if (msgId != null && _messages.any((m) => m['id'] == msgId)) return;

        _messages.add(msg);
        notifyListeners();
      }
    });
  }

  /// Send a text message via WebSocket with sender_role.
  void sendMessage(String conversationId, String content, {String? senderRole}) {
    if (content.trim().isEmpty) return;
    _service.sendChatMessage(conversationId, content, senderRole: senderRole);
  }

  // ===========================================================================
  // Attachment upload
  // ===========================================================================

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  /// Upload image or video attachment. The server suppresses the uploader's
  /// own WebSocket broadcast (sender_id match) and — unlike text — attachments
  /// get no direct WS echo, so we insert the returned message locally to show
  /// it on the sender's side immediately. [senderRole] is the uploader's acting
  /// role ("guard"/"customer"), passed through so bubbles align correctly.
  Future<void> uploadAttachment(
    String conversationId,
    File file,
    String mimeType, {
    String? senderRole,
  }) async {
    _isUploading = true;
    notifyListeners();
    try {
      final msg = await _service.uploadAttachment(
        conversationId,
        file,
        mimeType,
        senderRole: senderRole,
      );
      // Only insert into the active conversation; dedup by id mirrors the WS
      // listener guard in case a broadcast ever races in.
      final id = msg['id'] as String?;
      if (id != null &&
          conversationId == _activeConversationId &&
          !_messages.any((m) => m['id'] == id)) {
        _messages.add(msg);
      }
    } catch (e) {
      debugPrint('[ChatProvider] uploadAttachment error: $e');
    }
    _isUploading = false;
    notifyListeners();
  }

  /// Mark conversation as read for the given role.
  Future<void> markRead(String conversationId, {String? role}) async {
    try {
      await _service.markRead(conversationId, role: role);
    } catch (e) {
      debugPrint('[ChatProvider] markRead error: $e');
    }
  }

  /// Disconnect WebSocket and clear active conversation.
  Future<void> disconnect() async {
    _activeConversationId = null;
    _messages = [];
    await _service.disconnectChat();
  }

  // ===========================================================================
  // Conversation get-or-create
  // ===========================================================================

  /// Find or create a conversation for a booking request.
  Future<String> getOrCreateConversation(
    String requestId,
    String myUserId,
    String otherUserId,
  ) async {
    return _service.getOrCreateConversation(requestId, myUserId, otherUserId);
  }

  @override
  void dispose() {
    _service.disconnectChat();
    super.dispose();
  }
}
