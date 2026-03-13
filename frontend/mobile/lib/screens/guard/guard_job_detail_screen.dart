import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../call_screen.dart';
import '../chat_screen.dart';
import 'active_job_screen.dart';
import 'guard_navigation_screen.dart';

class GuardJobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const GuardJobDetailScreen({super.key, required this.job});

  @override
  State<GuardJobDetailScreen> createState() => _GuardJobDetailScreenState();
}

class _GuardJobDetailScreenState extends State<GuardJobDetailScreen> {
  static const _envBaseUrl = String.fromEnvironment('API_URL');
  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  Timer? _paymentTimer;
  late Map<String, dynamic> _job;

  // WebSocket for real-time status updates
  IOWebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    _startPaymentPollingIfNeeded();
    _connectAssignmentWs();
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _connectAssignmentWs() async {
    final requestId = _job['request_id'] as String? ?? _job['id'] as String? ?? '';
    if (requestId.isEmpty) return;

    final token = await AuthService.getAccessToken();
    if (token == null) return;

    final wsUrl = _defaultBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ws/assignments');

    try {
      _wsChannel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: const Duration(seconds: 30),
      );
      await _wsChannel!.ready;
      _wsChannel!.sink.add(requestId);

      _wsSub = _wsChannel!.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final status = msg['status'] as String?;
            if (status == 'accepted' && msg['type'] == 'status_changed') {
              _onPaymentConfirmed();
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _onPaymentConfirmed() {
    _paymentTimer?.cancel();
    _paymentTimer = null;
    final isThai = LanguageProvider.of(context).isThai;
    setState(() {
      _job['assignment_status'] = 'accepted';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isThai ? 'ลูกค้าชำระเงินแล้ว' : 'Customer has paid'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _startPaymentPollingIfNeeded() {
    final status = _job['assignment_status'] as String? ?? '';
    if (status == 'awaiting_payment') {
      _paymentTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollPaymentStatus());
    }
  }

  Future<void> _pollPaymentStatus() async {
    final requestId = _job['request_id'] as String? ?? _job['id'] as String? ?? '';
    if (requestId.isEmpty) return;
    try {
      final assignments = await context.read<BookingProvider>().getAssignments(requestId);
      if (!mounted) return;
      final assignmentId = _job['assignment_id'] as String?;
      final match = assignments.where((a) => a['id'] == assignmentId);
      if (match.isNotEmpty) {
        final newStatus = match.first['status'] as String?;
        if (newStatus == 'accepted') {
          _onPaymentConfirmed();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final isThai = LanguageProvider.of(context).isThai;

    final customerName = job['customer_name'] as String? ?? '-';
    final customerPhone = job['customer_phone'] as String?;
    final address = job['address'] as String? ?? '-';
    final description = job['description'] as String? ?? '';
    final specialInstructions = job['special_instructions'] as String?;
    final rawAssignmentStatus = job['assignment_status'] as String? ?? 'assigned';
    final startedAt = job['started_at'] as String?;
    // If status is 'arrived' but started_at is set, the job is in progress
    final assignmentStatus =
        (rawAssignmentStatus == 'arrived' && startedAt != null)
            ? 'started'
            : rawAssignmentStatus;
    final bookedHours = (job['booked_hours'] as num?)?.toInt();
    final price = job['offered_price'];
    final urgency = job['urgency'] as String? ?? 'medium';

    final detailLines = _parseDescription(description);
    final statusLabel = _statusLabel(assignmentStatus, isThai);
    final statusColor = _statusColor(assignmentStatus);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai ? 'รายละเอียดงาน' : 'Job Details',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (bookedHours != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$bookedHours ${isThai ? "ชม." : "hrs"}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Price header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: statusColor, size: 8),
                            const SizedBox(width: 8),
                            Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (price != null)
                        Text(
                          '฿${(price is num ? price : double.tryParse(price.toString()) ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Customer info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (customerPhone != null)
                                    Text(
                                      customerPhone,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Urgency badge
                  if (urgency != 'medium') ...[
                    const SizedBox(height: 12),
                    _buildChip(
                      Icons.flag_rounded,
                      _urgencyLabel(urgency, isThai),
                      _urgencyColor(urgency),
                    ),
                  ],

                  // Booking description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    // Extract first line as job summary if it's descriptive
                    if (detailLines.isEmpty)
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                  ],

                  // Structured detail lines
                  if (detailLines.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                isThai
                                    ? 'รายละเอียดการจอง'
                                    : 'Booking Details',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...detailLines.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(d.icon,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        d.text,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // Special instructions
                  if (specialInstructions != null &&
                      specialInstructions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Text(
                                isThai
                                    ? 'รายละเอียดเพิ่มเติมจากลูกค้า'
                                    : 'Additional Notes from Customer',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            specialInstructions,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF78350F),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action button area
                  if (assignmentStatus == 'pending_acceptance') ...[
                    const SizedBox(height: 24),
                    _buildAcceptDeclineButtons(context, isThai),
                  ] else if (assignmentStatus == 'awaiting_payment') ...[
                    const SizedBox(height: 24),
                    _buildAwaitingPaymentButton(isThai),
                  ] else if (assignmentStatus == 'accepted' ||
                      assignmentStatus == 'assigned' ||
                      assignmentStatus == 'en_route' ||
                      assignmentStatus == 'arrived' ||
                      assignmentStatus == 'started') ...[
                    const SizedBox(height: 24),
                    _buildStatusActionButton(context, isThai),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom call/chat bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(userName: customerName),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    label: Text(
                      isThai ? 'โทรหาลูกค้า' : 'Call Customer',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(context, isThai),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text(
                      isThai ? 'แชท' : 'Chat',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  Future<void> _openChat(BuildContext context, bool isThai) async {
    final requestId = _job['id'] as String? ?? '';
    final customerId = _job['customer_id'] as String? ?? '';
    final customerName = _job['customer_name'] as String? ?? '-';
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    var myUserId = authProvider.userId;
    if (myUserId == null) {
      await authProvider.fetchProfile();
      myUserId = authProvider.userId;
    }

    if (myUserId == null || requestId.isEmpty || customerId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'ไม่สามารถเปิดแชทได้' : 'Cannot open chat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final conversationId = await chatProvider
          .getOrCreateConversation(requestId, myUserId, customerId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            requestId: requestId,
            userName: customerName,
            userRole: isThai ? 'ลูกค้า' : 'Client',
            actingRole: 'guard',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // =========================================================================
  // Description parser
  // =========================================================================

  List<_DetailLine> _parseDescription(String description) {
    final lines = description.split('\n').where((l) => l.trim().isNotEmpty);
    final result = <_DetailLine>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      IconData icon;
      if (lower.startsWith('บริการ:') || lower.startsWith('service:')) {
        icon = Icons.shield_rounded;
      } else if (lower.startsWith('วันที่:') || lower.startsWith('date:')) {
        icon = Icons.calendar_today_rounded;
      } else if (lower.startsWith('ระยะเวลา:') ||
          lower.startsWith('duration:')) {
        icon = Icons.access_time_rounded;
      } else if (lower.startsWith('จำนวน') || lower.startsWith('guards:')) {
        icon = Icons.people_rounded;
      } else if (lower.startsWith('บริการเพิ่มเติม:') ||
          lower.startsWith('additional:')) {
        icon = Icons.add_circle_outline_rounded;
      } else if (lower.startsWith('อุปกรณ์:') ||
          lower.startsWith('equipment:')) {
        icon = Icons.construction_rounded;
      } else if (lower.startsWith('รายละเอียดงาน:') ||
          lower.startsWith('job details:')) {
        icon = Icons.description_rounded;
      } else {
        icon = Icons.info_outline_rounded;
      }
      result.add(_DetailLine(icon: icon, text: line.trim()));
    }
    return result;
  }

  // =========================================================================
  // Status helpers
  // =========================================================================

  String _statusLabel(String status, bool isThai) {
    switch (status) {
      case 'pending_acceptance':
        return isThai ? 'รอตอบรับ' : 'Pending Acceptance';
      case 'accepted':
        return isThai ? 'ตอบรับแล้ว' : 'Accepted';
      case 'awaiting_payment':
        return isThai ? 'รอชำระเงิน' : 'Awaiting Payment';
      case 'assigned':
        return isThai ? 'ได้รับมอบหมาย' : 'Assigned';
      case 'en_route':
        return isThai ? 'กำลังเดินทาง' : 'En Route';
      case 'arrived':
        return isThai ? 'ถึงจุดหมาย' : 'Arrived';
      case 'started':
        return isThai ? 'กำลังดำเนินงาน' : 'In Progress';
      case 'completed':
        return isThai ? 'เสร็จสิ้น' : 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_acceptance':
        return const Color(0xFFF59E0B);
      case 'accepted':
      case 'assigned':
        return AppColors.info;
      case 'awaiting_payment':
        return const Color(0xFFF59E0B);
      case 'en_route':
        return AppColors.warning;
      case 'arrived':
        return AppColors.success;
      case 'started':
        return AppColors.primary;
      case 'completed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _urgencyLabel(String urgency, bool isThai) {
    switch (urgency) {
      case 'high':
        return isThai ? 'เร่งด่วน' : 'Urgent';
      case 'critical':
        return isThai ? 'ฉุกเฉิน' : 'Critical';
      case 'low':
        return isThai ? 'ต่ำ' : 'Low';
      default:
        return isThai ? 'ปกติ' : 'Normal';
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
      case 'critical':
        return AppColors.danger;
      case 'low':
        return AppColors.success;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Action buttons
  // =========================================================================

  Widget _buildAcceptDeclineButtons(BuildContext context, bool isThai) {
    final assignmentId = _job['assignment_id'] as String? ?? '';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    isThai ? 'ปฏิเสธงาน' : 'Decline Job',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  content: Text(isThai
                      ? 'คุณต้องการปฏิเสธงานนี้หรือไม่?'
                      : 'Decline this job?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context
                            .read<BookingProvider>()
                            .declineAssignment(assignmentId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isThai ? 'ปฏิเสธ' : 'Decline'),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isThai ? 'ปฏิเสธ' : 'Decline',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              context.read<BookingProvider>().acceptAssignment(assignmentId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isThai ? 'รับงาน' : 'Accept',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwaitingPaymentButton(bool isThai) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isThai
                      ? 'กรุณารอลูกค้าชำระเงิน\nเมื่อชำระเงินแล้วจะสามารถเริ่มเดินทางได้'
                      : 'Waiting for customer payment.\nYou can start the route after payment is confirmed.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_top_rounded, size: 22),
            label: Text(
              isThai ? 'รอลูกค้าชำระเงิน' : 'Awaiting Payment',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              disabledBackgroundColor:
                  const Color(0xFFF59E0B).withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActionButton(BuildContext context, bool isThai) {
    final assignmentId = _job['assignment_id'] as String? ?? '';
    final rawStatus = _job['assignment_status'] as String? ?? 'assigned';
    final startedAt = _job['started_at'] as String?;
    final status = (rawStatus == 'arrived' && startedAt != null) ? 'started' : rawStatus;

    String buttonLabel;
    IconData buttonIcon;
    if (status == 'started') {
      buttonLabel = isThai ? 'ดูเวลาทำงาน' : 'View Timer';
      buttonIcon = Icons.timer_rounded;
    } else if (status == 'accepted' || status == 'assigned') {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      buttonIcon = Icons.directions_car_rounded;
    } else if (status == 'en_route') {
      buttonLabel = isThai ? 'ดูแผนที่นำทาง' : 'View Navigation';
      buttonIcon = Icons.map_rounded;
    } else if (status == 'arrived') {
      buttonLabel = isThai ? 'เริ่มงาน' : 'Start Job';
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      buttonIcon = Icons.directions_car_rounded;
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (status == 'started') {
            // Resume active job countdown
            try {
              final activeJob = await context
                  .read<BookingProvider>()
                  .fetchActiveJobData();
              if (!context.mounted) return;
              if (activeJob != null) {
                final remaining =
                    (activeJob['remaining_seconds'] as num?)?.toInt() ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveJobScreen(
                      assignmentId: assignmentId,
                      customerName: _job['customer_name'] as String?,
                      address: _job['address'] as String?,
                      bookedHours:
                          (_job['booked_hours'] as num?)?.toInt() ?? 6,
                      remainingSeconds: remaining,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          } else if (status == 'arrived') {
            try {
              final result = await context
                  .read<BookingProvider>()
                  .startActiveJob(assignmentId);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveJobScreen(
                    assignmentId: assignmentId,
                    customerName: _job['customer_name'] as String?,
                    address: _job['address'] as String?,
                    bookedHours:
                        (_job['booked_hours'] as num?)?.toInt() ?? 6,
                    remainingSeconds:
                        (result['remaining_seconds'] as num?)?.toInt() ??
                            (((_job['booked_hours'] as num?)?.toInt() ?? 6) *
                                3600),
                  ),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          } else if (status == 'accepted' || status == 'assigned') {
            // Start Route → update status + navigate to map navigation
            final customerLat = (_job['location_lat'] as num?)?.toDouble();
            final customerLng = (_job['location_lng'] as num?)?.toDouble();
            await context
                .read<BookingProvider>()
                .updateAssignmentStatus(assignmentId, 'en_route');
            if (!context.mounted) return;
            if (customerLat != null && customerLng != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardNavigationScreen(
                    assignmentId: assignmentId,
                    customerName: _job['customer_name'] as String? ?? '-',
                    customerPhone: _job['customer_phone'] as String?,
                    address: _job['address'] as String? ?? '-',
                    customerLat: customerLat,
                    customerLng: customerLng,
                  ),
                ),
              );
            } else {
              Navigator.pop(context);
            }
          } else {
            // en_route → open navigation map
            final customerLat = (_job['location_lat'] as num?)?.toDouble();
            final customerLng = (_job['location_lng'] as num?)?.toDouble();
            if (customerLat != null && customerLng != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardNavigationScreen(
                    assignmentId: assignmentId,
                    customerName: _job['customer_name'] as String? ?? '-',
                    customerPhone: _job['customer_phone'] as String?,
                    address: _job['address'] as String? ?? '-',
                    customerLat: customerLat,
                    customerLng: customerLng,
                  ),
                ),
              );
            }
          }
        },
        icon: Icon(buttonIcon, size: 22),
        label: Text(
          buttonLabel,
          style:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _DetailLine {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});
}
