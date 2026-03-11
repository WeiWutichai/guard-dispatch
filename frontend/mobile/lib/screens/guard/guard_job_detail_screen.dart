import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/language_service.dart';
import '../call_screen.dart';
import '../chat_screen.dart';
import 'active_job_screen.dart';

class GuardJobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const GuardJobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    final customerName = job['customer_name'] as String? ?? '-';
    final customerPhone = job['customer_phone'] as String?;
    final address = job['address'] as String? ?? '-';
    final description = job['description'] as String? ?? '';
    final specialInstructions = job['special_instructions'] as String?;
    final assignmentStatus = job['assignment_status'] as String? ?? 'assigned';
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
                  ] else if (assignmentStatus == 'accepted' ||
                      assignmentStatus == 'assigned' ||
                      assignmentStatus == 'en_route' ||
                      assignmentStatus == 'arrived') ...[
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
    final requestId = job['id'] as String? ?? '';
    final customerId = job['customer_id'] as String? ?? '';
    final customerName = job['customer_name'] as String? ?? '-';
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
      case 'assigned':
        return isThai ? 'ได้รับมอบหมาย' : 'Assigned';
      case 'en_route':
        return isThai ? 'กำลังเดินทาง' : 'En Route';
      case 'arrived':
        return isThai ? 'ถึงจุดหมาย' : 'Arrived';
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
      case 'en_route':
        return AppColors.warning;
      case 'arrived':
        return AppColors.success;
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
    final assignmentId = job['assignment_id'] as String? ?? '';

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

  Widget _buildStatusActionButton(BuildContext context, bool isThai) {
    final assignmentId = job['assignment_id'] as String? ?? '';
    final status = job['assignment_status'] as String? ?? 'assigned';

    String buttonLabel;
    IconData buttonIcon;
    if (status == 'accepted' || status == 'assigned') {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      buttonIcon = Icons.directions_car_rounded;
    } else if (status == 'en_route') {
      buttonLabel = isThai ? 'ถึงจุดหมาย' : 'Arrived';
      buttonIcon = Icons.location_on_rounded;
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
          if (status == 'arrived') {
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
                    customerName: job['customer_name'] as String?,
                    address: job['address'] as String?,
                    bookedHours:
                        (job['booked_hours'] as num?)?.toInt() ?? 6,
                    remainingSeconds:
                        (result['remaining_seconds'] as num?)?.toInt() ??
                            (((job['booked_hours'] as num?)?.toInt() ?? 6) *
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
          } else {
            final nextStatus =
                (status == 'accepted' || status == 'assigned')
                    ? 'en_route'
                    : 'arrived';
            context
                .read<BookingProvider>()
                .updateAssignmentStatus(assignmentId, nextStatus);
            if (context.mounted) Navigator.pop(context);
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
