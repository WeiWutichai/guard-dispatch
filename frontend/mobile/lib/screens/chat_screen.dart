import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const ChatScreen({super.key, required this.userName, required this.userRole});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = ChatStrings(isThai: isThai);

    // Mock messages for display
    final List<Widget> messages = [
      _buildMessageBubble(
        text: isThai
            ? "สวัสดีครับ คุณสมชาย วีรชน เจ้าหน้าที่รักษาความปลอดภัยที่ได้รับมอบหมาย"
            : "Hello, Somchai Wirachon, your assigned security officer.",
        isMe: false,
        time: "14:30",
      ),
      _buildMessageBubble(
        text: isThai
            ? "ผมกำลังเดินทางไปยังสถานที่ของคุณ คาดว่าจะถึงใน 15 นาที"
            : "I'm on my way to your location, expected in 15 mins.",
        isMe: false,
        time: "14:31",
      ),
      _buildMessageBubble(
        text: isThai
            ? "สวัสดีครับ ขอบคุณที่แจ้งให้ทราบ"
            : "Hello, thanks for letting me know.",
        isMe: true,
        time: "14:32",
      ),
      _buildMessageBubble(
        text: isThai
            ? "ถ้ามีข้อสงสัยหรือต้องการติดต่ออะไร สามารถโทรหาผมได้ตลอดเวลาครับ"
            : "If you have questions, feel free to call anytime.",
        isMe: false,
        time: "14:33",
      ),
      _buildSystemEvent(
        context,
        s,
        title: isThai ? 'การลงชื่อเข้างาน' : 'Check-in Notification',
        time: '14:45',
        details: isThai
            ? 'คุณ สมชาย วีรชน ได้เช็คอินที่ อาคารสำนักงาน สุขุมวิท 23'
            : 'Somchai Wirachon checked in at Sukhumvit 23 Office.',
        gps: '15/02/2568  14:45',
      ),
      _buildMessageBubble(
        text: isThai
            ? "ผมถึงแล้วครับ เริ่มปฏิบัติงานเลยครับ"
            : "I've arrived. Starting duty now.",
        isMe: false,
        time: "14:48",
      ),
      _buildReportCard(
        context,
        s,
        index: 1,
        time: '15:45',
        location: isThai ? 'อาคารสำนักงาน สุขุมวิท 23' : 'Sukhumvit 23 Office',
        imageUrl:
            'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=400',
        status: isThai
            ? 'ปกติ พื้นที่ปลอดภัย ไม่มีเหตุการณ์ผิดปกติ'
            : 'Normal, area secure, no incidents.',
      ),
      _buildReportCard(
        context,
        s,
        index: 2,
        time: '16:45',
        location: isThai ? 'อาคารสำนักงาน สุขุมวิท 23' : 'Sukhumvit 23 Office',
        imageUrl:
            'https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=400',
        status: isThai
            ? 'ตรวจรอบอาคารเรียบร้อย ทุกจุดปลอดภัย'
            : 'Patrolled around building, all secure.',
      ),
    ];

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
              backgroundImage: const NetworkImage(
                'https://i.pravatar.cc/150?u=1',
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
                  s.online,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.success,
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messages.length,
              itemBuilder: (context, index) => messages[index],
            ),
          ),
          _buildMessageInput(s),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40) else const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSystemEvent(
    BuildContext context,
    ChatStrings s, {
    required String title,
    required String time,
    required String details,
    required String gps,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                gps,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 12,
                color: AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                s.viewLocation,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.success,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ChatStrings s, {
    required int index,
    required String time,
    required String location,
    required String imageUrl,
    required String status,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.hourlyReport,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.hourlyReport} ที่ $index',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.photo_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.photoReport,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.attach_file_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: s.typeMessage,
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
