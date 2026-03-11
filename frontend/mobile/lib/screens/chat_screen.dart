import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/chat_provider.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String requestId;
  final String userName;
  final String userRole;
  final String? actingRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.requestId,
    required this.userName,
    required this.userRole,
    this.actingRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.fetchMessages(widget.conversationId).then((_) {
        _scrollToBottom();
      });
      chatProvider.connectToConversation(widget.conversationId);
      // Mark as read on open
      chatProvider.markRead(widget.conversationId, role: widget.actingRole);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    try {
      context.read<ChatProvider>().disconnect();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatProvider>().sendMessage(
      widget.conversationId,
      text,
      senderRole: widget.actingRole,
    );
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = ChatStrings(isThai: isThai);
    final chatProvider = context.watch<ChatProvider>();

    // Scroll to bottom when new messages arrive
    if (chatProvider.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.userRole,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(userName: widget.userName),
                ),
              );
            },
            icon: const Icon(Icons.call_outlined),
            color: AppColors.textSecondary,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(chatProvider)),
          _buildMessageInput(s),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chatProvider) {
    if (chatProvider.isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = chatProvider.messages;

    if (messages.isEmpty) {
      final isThai = LanguageProvider.of(context).isThai;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              isThai ? 'เริ่มสนทนา' : 'Start a conversation',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final senderRole = msg['sender_role'] as String?;
        // Use sender_role to determine sides: if sender_role matches my acting role → right (me)
        final isMe = widget.actingRole != null && senderRole == widget.actingRole;
        final content = msg['content'] as String? ?? '';
        final createdAt = msg['created_at'] as String?;
        final time = _formatMessageTime(createdAt);
        final isLastInGroup = index == messages.length - 1 ||
            (messages[index + 1]['sender_role'] as String?) != senderRole;

        return _buildMessageBubble(
          text: content,
          isMe: isMe,
          time: time,
          showReadStatus: isMe && isLastInGroup,
        );
      },
    );
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String time,
    bool showReadStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          showReadStatus ? Icons.done_all : Icons.done,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ChatStrings s) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: s.typeMessage,
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
