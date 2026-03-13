import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import 'review_rating_screen.dart';

/// Detail screen for a completed booking — customer side.
/// Shows booking details, guard info, timeline, and payment summary.
class CustomerCompletedJobScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CustomerCompletedJobScreen({super.key, required this.request});

  @override
  State<CustomerCompletedJobScreen> createState() =>
      _CustomerCompletedJobScreenState();
}

class _CustomerCompletedJobScreenState
    extends State<CustomerCompletedJobScreen> {
  Map<String, dynamic>? _assignment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignment();
  }

  Future<void> _fetchAssignment() async {
    final requestId = widget.request['id'] as String? ?? '';
    if (requestId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final assignments =
          await context.read<BookingProvider>().getAssignments(requestId);
      if (!mounted) return;
      // Find the completed assignment
      final completed = assignments.where(
        (a) => a['status'] == 'completed',
      );
      setState(() {
        _assignment = completed.isNotEmpty ? completed.first : assignments.isNotEmpty ? assignments.first : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final req = widget.request;

    final address = req['address'] as String? ?? '-';
    final description = req['description'] as String? ?? '';
    final specialInstructions = req['special_instructions'] as String?;
    final bookedHours = (req['booked_hours'] as num?)?.toInt();
    final price = req['offered_price'];
    final urgency = req['urgency'] as String? ?? 'medium';
    final createdAt = req['created_at'] as String?;

    // Assignment data (fetched async)
    final guardName = _assignment?['guard_name'] as String?;
    final assignedAt = _assignment?['assigned_at'] as String?;
    final arrivedAt = _assignment?['arrived_at'] as String?;
    final startedAt = _assignment?['started_at'] as String?;
    final completedAt = _assignment?['completed_at'] as String?;

    final detailLines = _parseDescription(description);

    // Calculate actual work duration
    String? workDuration;
    if (startedAt != null && completedAt != null) {
      final start = DateTime.tryParse(startedAt);
      final end = DateTime.tryParse(completedAt);
      if (start != null && end != null) {
        final diff = end.difference(start);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        if (hours > 0 && minutes > 0) {
          workDuration = isThai
              ? '$hours ชั่วโมง $minutes นาที'
              : '${hours}h ${minutes}m';
        } else if (hours > 0) {
          workDuration = isThai ? '$hours ชั่วโมง' : '${hours}h';
        } else {
          workDuration = isThai ? '$minutes นาที' : '${minutes}m';
        }
      }
    }

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
                        isThai ? 'สรุปรายการจ้าง' : 'Booking Summary',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatDateTime(completedAt ?? createdAt, isThai),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        isThai ? 'เสร็จสิ้น' : 'Done',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment + Duration summary card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFF0FDF4),
                                Color(0xFFECFDF5)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isThai ? 'ค่าบริการ' : 'Total Cost',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      price != null
                                          ? '฿${(price is num ? price : double.tryParse(price.toString()) ?? 0).toStringAsFixed(0)}'
                                          : '-',
                                      style: GoogleFonts.inter(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: AppColors.primary
                                    .withValues(alpha: 0.2),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isThai
                                          ? 'ระยะเวลาทำงาน'
                                          : 'Work Duration',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      workDuration ?? '-',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (bookedHours != null)
                                      Text(
                                        isThai
                                            ? 'จอง $bookedHours ชม.'
                                            : 'Booked: ${bookedHours}h',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Guard info card
                        if (guardName != null)
                          _buildSectionCard(
                            icon: Icons.security_rounded,
                            title: isThai
                                ? 'เจ้าหน้าที่รักษาความปลอดภัย'
                                : 'Security Guard',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primary,
                                      size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    guardName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (guardName != null) const SizedBox(height: 16),

                        // Location card
                        _buildSectionCard(
                          icon: Icons.location_on_rounded,
                          title: isThai ? 'สถานที่' : 'Location',
                          child: Text(
                            address,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),

                        // Urgency badge
                        if (urgency != 'medium' && urgency != 'normal') ...[
                          const SizedBox(height: 12),
                          _buildChip(
                            Icons.flag_rounded,
                            _urgencyLabel(urgency, isThai),
                            _urgencyColor(urgency),
                          ),
                        ],

                        // Booking details
                        if (detailLines.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            icon: Icons.description_rounded,
                            title: isThai
                                ? 'รายละเอียดการจอง'
                                : 'Booking Details',
                            backgroundColor: const Color(0xFFF0FDF4),
                            borderColor:
                                AppColors.primary.withValues(alpha: 0.2),
                            child: Column(
                              children: detailLines
                                  .map((d) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 10),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(d.icon,
                                                size: 16,
                                                color: AppColors.primary),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                d.text,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: AppColors
                                                      .textPrimary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
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
                              border: Border.all(
                                  color: const Color(0xFFFED7AA)),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      isThai
                                          ? 'หมายเหตุเพิ่มเติม'
                                          : 'Additional Notes',
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

                        // Review / Rating
                        if (_assignment?['review_overall_rating'] != null) ...[
                          const SizedBox(height: 20),
                          _buildReviewCard(isThai),
                        ] else if (_assignment != null &&
                            _assignment!['status'] == 'completed') ...[
                          const SizedBox(height: 20),
                          _buildWriteReviewButton(isThai),
                        ],

                        // Timeline
                        const SizedBox(height: 24),
                        _buildTimeline(
                          isThai: isThai,
                          createdAt: createdAt,
                          assignedAt: assignedAt,
                          arrivedAt: arrivedAt,
                          startedAt: startedAt,
                          completedAt: completedAt,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Write Review button (no review yet)
  // =========================================================================

  Widget _buildWriteReviewButton(bool isThai) {
    final assignmentId = _assignment!['id'] as String;
    final guardName = _assignment!['guard_name'] as String? ?? '-';

    return _buildSectionCard(
      icon: Icons.rate_review_rounded,
      title: isThai ? 'ให้คะแนนเจ้าหน้าที่' : 'Rate Guard',
      backgroundColor: const Color(0xFFFFFBEB),
      borderColor: Colors.amber.withValues(alpha: 0.3),
      child: Column(
        children: [
          Text(
            isThai
                ? 'คุณยังไม่ได้ให้คะแนนเจ้าหน้าที่สำหรับงานนี้'
                : 'You haven\'t rated the guard for this job yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewRatingScreen(
                      assignmentId: assignmentId,
                      guardName: guardName,
                      popToHome: false,
                    ),
                  ),
                );
                // Refresh assignment data to show review after returning
                _fetchAssignment();
              },
              icon: const Icon(Icons.star_rounded, size: 20),
              label: Text(
                isThai ? 'เขียนรีวิว' : 'Write Review',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Review / Rating card
  // =========================================================================

  Widget _buildReviewCard(bool isThai) {
    final overall = (_assignment?['review_overall_rating'] as num?)?.toDouble() ?? 0;
    final punctuality = (_assignment?['review_punctuality'] as num?)?.toDouble();
    final professionalism = (_assignment?['review_professionalism'] as num?)?.toDouble();
    final communication = (_assignment?['review_communication'] as num?)?.toDouble();
    final appearance = (_assignment?['review_appearance'] as num?)?.toDouble();
    final reviewText = _assignment?['review_text'] as String?;

    return _buildSectionCard(
      icon: Icons.star_rounded,
      title: isThai ? 'รีวิวของคุณ' : 'Your Review',
      backgroundColor: const Color(0xFFFFFBEB),
      borderColor: Colors.amber.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall stars
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                i < overall.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 28,
                color: i < overall.round() ? Colors.amber : AppColors.disabled,
              )),
              const SizedBox(width: 8),
              Text(
                overall.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          // Category ratings
          if (punctuality != null || professionalism != null ||
              communication != null || appearance != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.amber.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            if (punctuality != null)
              _buildMiniRatingRow(isThai ? 'ตรงต่อเวลา' : 'Punctuality', punctuality),
            if (professionalism != null)
              _buildMiniRatingRow(isThai ? 'ความเป็นมืออาชีพ' : 'Professionalism', professionalism),
            if (communication != null)
              _buildMiniRatingRow(isThai ? 'การสื่อสาร' : 'Communication', communication),
            if (appearance != null)
              _buildMiniRatingRow(isThai ? 'บุคลิกภาพ' : 'Appearance', appearance),
          ],
          // Review text
          if (reviewText != null && reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.amber.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              '"$reviewText"',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRatingRow(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...List.generate(5, (i) => Icon(
            i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: i < rating.round() ? Colors.amber : AppColors.disabled,
          )),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Timeline
  // =========================================================================

  Widget _buildTimeline({
    required bool isThai,
    String? createdAt,
    String? assignedAt,
    String? arrivedAt,
    String? startedAt,
    String? completedAt,
  }) {
    final events = <_TimelineEvent>[];

    if (createdAt != null) {
      events.add(_TimelineEvent(
        label: isThai ? 'สร้างคำขอ' : 'Request Created',
        time: createdAt,
        icon: Icons.add_circle_outline_rounded,
        color: AppColors.info,
      ));
    }
    if (assignedAt != null) {
      events.add(_TimelineEvent(
        label: isThai ? 'มอบหมายเจ้าหน้าที่' : 'Guard Assigned',
        time: assignedAt,
        icon: Icons.assignment_turned_in_rounded,
        color: AppColors.info,
      ));
    }
    if (arrivedAt != null) {
      events.add(_TimelineEvent(
        label: isThai ? 'เจ้าหน้าที่ถึงจุดหมาย' : 'Guard Arrived',
        time: arrivedAt,
        icon: Icons.location_on_rounded,
        color: AppColors.warning,
      ));
    }
    if (startedAt != null) {
      events.add(_TimelineEvent(
        label: isThai ? 'เริ่มทำงาน' : 'Job Started',
        time: startedAt,
        icon: Icons.play_circle_rounded,
        color: AppColors.primary,
      ));
    }
    if (completedAt != null) {
      events.add(_TimelineEvent(
        label: isThai ? 'งานเสร็จสิ้น' : 'Job Completed',
        time: completedAt,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      ));
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline_rounded,
                size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              isThai ? 'ไทม์ไลน์' : 'Timeline',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(events.length, (i) {
          final event = events[i];
          final isLast = i == events.length - 1;
          return _buildTimelineRow(event, isLast, isThai);
        }),
      ],
    );
  }

  Widget _buildTimelineRow(
      _TimelineEvent event, bool isLast, bool isThai) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 18, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(event.time, isThai),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Color backgroundColor = const Color(0xFFF8FAFC),
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
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

  String _formatDateTime(String? isoString, bool isThai) {
    if (isoString == null || isoString.isEmpty) return '-';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = isThai
        ? ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
           'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
        : ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month]} ${local.year} $hour:$minute';
  }

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

  String _urgencyLabel(String urgency, bool isThai) {
    switch (urgency) {
      case 'high':
      case 'urgent':
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
      case 'urgent':
        return AppColors.danger;
      case 'low':
        return AppColors.success;
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

class _TimelineEvent {
  final String label;
  final String time;
  final IconData icon;
  final Color color;
  const _TimelineEvent({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class _DetailLine {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});
}
