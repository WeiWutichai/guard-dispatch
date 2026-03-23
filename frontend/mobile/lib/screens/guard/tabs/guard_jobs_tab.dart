import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../call_screen.dart';
import '../../../theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../services/language_service.dart';
import '../../../l10n/app_strings.dart';
import '../../chat_screen.dart';
import '../active_job_screen.dart';
import '../guard_job_detail_screen.dart';
import '../completed_job_detail_screen.dart';
import '../guard_navigation_screen.dart';

class GuardJobsTab extends StatefulWidget {
  const GuardJobsTab({super.key});

  @override
  State<GuardJobsTab> createState() => _GuardJobsTabState();
}

class _GuardJobsTabState extends State<GuardJobsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardJobsStrings(isThai: isThai);
    final booking = context.watch<BookingProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 60, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SecureGuard',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              strings.appBarTitle,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.white,
                      labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(text: '${strings.currentTabLabel} (${booking.currentJobs.length})'),
                        Tab(text: '${strings.completedTabLabel} (${booking.completedJobs.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCurrentJobs(strings, isThai),
                  _buildCompletedJobs(strings, isThai),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    final num amount = value is num ? value : 0;
    if (amount >= 1000) {
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return '฿$formatted';
    }
    return '฿${amount.toStringAsFixed(0)}';
  }

  Widget _buildCurrentJobs(GuardJobsStrings strings, bool isThai) {
    final provider = context.watch<BookingProvider>();
    final jobs = provider.currentJobs;

    if (provider.isLoading && jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              isThai ? 'ยังไม่มีงานปัจจุบัน' : 'No current jobs',
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BookingProvider>().fetchJobs(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < jobs.length - 1 ? 16 : 0),
            child: GestureDetector(
              onTap: () async {
                final provider = context.read<BookingProvider>();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuardJobDetailScreen(job: job),
                  ),
                );
                if (mounted) provider.fetchJobs();
              },
              child: _buildJobCard(job, strings, isThai),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedJobs(GuardJobsStrings strings, bool isThai) {
    final provider = context.watch<BookingProvider>();
    final jobs = provider.completedJobs;

    if (provider.isLoading && jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              isThai ? 'ยังไม่มีงานที่เสร็จสิ้น' : 'No completed jobs yet',
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BookingProvider>().fetchJobs(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < jobs.length - 1 ? 16 : 0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompletedJobDetailScreen(job: job),
                  ),
                );
              },
              child: _buildJobCard(job, strings, isThai),
            ),
          );
        },
      ),
    );
  }

  /// Parse the description field into structured detail lines.
  /// The booking screen builds it as "Label: Value\n..." so we split and
  /// assign icons per known prefix.
  List<_DetailLine> _parseDescription(String description, bool isThai) {
    final lines = description.split('\n').where((l) => l.trim().isNotEmpty);
    final result = <_DetailLine>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      IconData icon;
      if (lower.startsWith('บริการ:') || lower.startsWith('service:')) {
        icon = Icons.shield_rounded;
      } else if (lower.startsWith('วันที่:') || lower.startsWith('date:')) {
        icon = Icons.calendar_today_rounded;
      } else if (lower.startsWith('ระยะเวลา:') || lower.startsWith('duration:')) {
        icon = Icons.access_time_rounded;
      } else if (lower.startsWith('จำนวน') || lower.startsWith('guards:')) {
        icon = Icons.people_rounded;
      } else if (lower.startsWith('ประเภทงาน:') ||
          lower.startsWith('job type:')) {
        icon = Icons.work_rounded;
      } else if (lower.startsWith('บริการเพิ่มเติม:') || lower.startsWith('additional:')) {
        icon = Icons.add_circle_outline_rounded;
      } else if (lower.startsWith('อุปกรณ์:') || lower.startsWith('equipment:')) {
        icon = Icons.construction_rounded;
      } else if (lower.startsWith('รายละเอียดงาน:') || lower.startsWith('job details:')) {
        icon = Icons.description_rounded;
      } else {
        icon = Icons.info_outline_rounded;
      }
      result.add(_DetailLine(icon: icon, text: line.trim()));
    }
    return result;
  }

  /// Derive effective status: if raw is 'arrived' but started_at is set → 'started'
  String _effectiveStatus(Map<String, dynamic> job) {
    final raw = job['assignment_status'] as String? ?? 'assigned';
    final startedAt = job['started_at'] as String?;
    return (raw == 'arrived' && startedAt != null) ? 'started' : raw;
  }

  Widget _buildJobCard(Map<String, dynamic> job, GuardJobsStrings strings, bool isThai) {
    final address = job['address'] as String? ?? '-';
    final price = _formatCurrency(job['offered_price']);
    final description = job['description'] as String? ?? '';
    final specialInstructions = job['special_instructions'] as String?;
    final assignmentStatus = _effectiveStatus(job);
    final bookedHours = (job['booked_hours'] as num?)?.toInt();
    final urgency = job['urgency'] as String?;

    final statusLabel = _getStatusLabel(assignmentStatus, isThai);
    final statusColor = _getStatusColor(assignmentStatus);
    final detailLines = _parseDescription(description, isThai);
    final createdAt = job['assigned_at'] as String? ?? job['created_at'] as String? ?? '';
    final completedAt = job['completed_at'] as String? ?? '';
    final dateStr = completedAt.isNotEmpty ? completedAt : createdAt;
    final dateDisplay = _formatDate(dateStr, isThai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Price row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Urgency + booked hours + date chips
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (urgency != null)
                _buildInfoChip(
                  Icons.flag_rounded,
                  _urgencyLabel(urgency, isThai),
                  _urgencyColor(urgency),
                ),
              if (bookedHours != null)
                _buildInfoChip(
                  Icons.access_time_rounded,
                  '$bookedHours ${isThai ? "ชม." : "hrs"}',
                  AppColors.info,
                ),
              if (dateDisplay != '-')
                _buildInfoChip(
                  Icons.calendar_today_rounded,
                  dateDisplay,
                  AppColors.textSecondary,
                ),
            ],
          ),

          // Structured description details
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            ...detailLines.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(d.icon, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Special instructions
          if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        isThai ? 'หมายเหตุ' : 'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialInstructions,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF78350F),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (assignmentStatus == 'pending_acceptance') ...[
            const SizedBox(height: 20),
            _buildAcceptDeclineButtons(job, isThai),
          ] else if (assignmentStatus == 'accepted' ||
              assignmentStatus == 'assigned' ||
              assignmentStatus == 'en_route' ||
              assignmentStatus == 'arrived' ||
              assignmentStatus == 'started') ...[
            const SizedBox(height: 20),
            _buildStatusActionButton(job, isThai),
            const SizedBox(height: 12),
            _buildCallChatRow(job, isThai),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptDeclineButtons(Map<String, dynamic> job, bool isThai) {
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
                  content: Text(
                    isThai
                        ? 'คุณต้องการปฏิเสธงานนี้หรือไม่?'
                        : 'Are you sure you want to decline this job?',
                  ),
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
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isThai ? 'ปฏิเสธ' : 'Decline',
              style:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              context.read<BookingProvider>().acceptAssignment(assignmentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 48),
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

  Widget _buildStatusActionButton(Map<String, dynamic> job, bool isThai) {
    final assignmentId = job['assignment_id'] as String? ?? '';
    final status = _effectiveStatus(job);

    String buttonLabel;
    IconData buttonIcon;
    if (status == 'started') {
      buttonLabel = isThai ? 'ดูเวลาทำงาน' : 'View Timer';
      buttonIcon = Icons.timer_rounded;
    } else if (status == 'accepted' || status == 'assigned') {
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

    return ElevatedButton.icon(
      onPressed: () async {
        if (status == 'started') {
          // Resume active job countdown
          try {
            final activeJob = await context
                .read<BookingProvider>()
                .fetchActiveJobData();
            if (!mounted) return;
            if (activeJob != null) {
              final remaining =
                  (activeJob['remaining_seconds'] as num?)?.toInt() ?? 0;
              final bookedHours =
                  (activeJob['booked_hours'] as num?)?.toInt() ??
                      (job['booked_hours'] as num?)?.toInt() ?? 6;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveJobScreen(
                    assignmentId: assignmentId,
                    customerName: job['customer_name'] as String?,
                    address: job['address'] as String?,
                    bookedHours: bookedHours,
                    remainingSeconds: remaining,
                    startedAt: activeJob['started_at'] as String?,
                  ),
                ),
              );
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.danger,
              ),
            );
          }
        } else if (status == 'arrived') {
          // Start job → navigate to ActiveJobScreen
          try {
            // Capture GPS at job start
            double? startLat, startLng;
            try {
              final pos = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
              );
              startLat = pos.latitude;
              startLng = pos.longitude;
            } catch (_) {}
            final result = await context
                .read<BookingProvider>()
                .startActiveJob(assignmentId, lat: startLat, lng: startLng);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActiveJobScreen(
                  assignmentId: assignmentId,
                  customerName: job['customer_name'] as String?,
                  address: job['address'] as String?,
                  bookedHours: (job['booked_hours'] as num?)?.toInt() ?? 6,
                  remainingSeconds:
                      (result['remaining_seconds'] as num?)?.toInt() ??
                          (((job['booked_hours'] as num?)?.toInt() ?? 6) * 3600),
                  startedAt: result['started_at'] as String?,
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.danger,
              ),
            );
          }
        } else if (status == 'accepted' || status == 'assigned') {
          // Start route → update status + navigate to map
          try {
            double? gpsLat, gpsLng;
            try {
              final pos = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
              );
              gpsLat = pos.latitude;
              gpsLng = pos.longitude;
            } catch (_) {}
            if (!mounted) return;
            await context
                .read<BookingProvider>()
                .updateAssignmentStatus(assignmentId, 'en_route', lat: gpsLat, lng: gpsLng);
            if (!mounted) return;
            final customerLat = (job['location_lat'] as num?)?.toDouble();
            final customerLng = (job['location_lng'] as num?)?.toDouble();
            if (customerLat != null && customerLng != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardNavigationScreen(
                    assignmentId: assignmentId,
                    customerName: job['customer_name'] as String? ?? '-',
                    customerPhone: job['customer_phone'] as String?,
                    address: job['address'] as String? ?? '-',
                    customerLat: customerLat,
                    customerLng: customerLng,
                  ),
                ),
              );
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.danger,
              ),
            );
          }
        } else if (status == 'en_route') {
          // Already en route → open navigation map
          final customerLat = (job['location_lat'] as num?)?.toDouble();
          final customerLng = (job['location_lng'] as num?)?.toDouble();
          if (customerLat != null && customerLng != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardNavigationScreen(
                  assignmentId: assignmentId,
                  customerName: job['customer_name'] as String? ?? '-',
                  customerPhone: job['customer_phone'] as String?,
                  address: job['address'] as String? ?? '-',
                  customerLat: customerLat,
                  customerLng: customerLng,
                ),
              ),
            );
          }
        } else {
          // Fallback: update status
          context
              .read<BookingProvider>()
              .updateAssignmentStatus(assignmentId, 'arrived');
        }
      },
      icon: Icon(buttonIcon, size: 20),
      label: Text(
        buttonLabel,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildCallChatRow(Map<String, dynamic> job, bool isThai) {
    final customerName = job['customer_name'] as String? ?? '-';

    return Row(
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
            icon: const Icon(Icons.phone_rounded, size: 18),
            label: Text(
              isThai ? 'โทร' : 'Call',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openChat(job, isThai),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text(
              isThai ? 'แชท' : 'Chat',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openChat(Map<String, dynamic> job, bool isThai) async {
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

    if (myUserId == null || requestId.isEmpty || customerId.isEmpty) return;
    try {
      final conversationId = await chatProvider
          .getOrCreateConversation(requestId, myUserId, customerId);
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _getStatusLabel(String status, bool isThai) {
    switch (status) {
      case 'pending_acceptance':
        return isThai ? 'รอตอบรับ' : 'Pending';
      case 'accepted':
        return isThai ? 'ตอบรับแล้ว' : 'Accepted';
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
      case 'awaiting_payment':
        return isThai ? 'กำลังรอการชำระ' : 'Awaiting Payment';
      case 'declined':
        return isThai ? 'ปฏิเสธแล้ว' : 'Declined';
      case 'pending_completion':
        return isThai ? 'รอลูกค้าตรวจสอบ' : 'Pending Review';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_acceptance':
        return const Color(0xFFF59E0B);
      case 'accepted':
        return AppColors.info;
      case 'assigned':
        return AppColors.info;
      case 'en_route':
        return AppColors.warning;
      case 'arrived':
        return AppColors.success;
      case 'started':
        return AppColors.primary;
      case 'pending_completion':
        return Colors.orange;
      case 'completed':
        return AppColors.textSecondary;
      case 'awaiting_payment':
        return const Color(0xFFF59E0B);
      case 'declined':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String isoDate, bool isThai) {
    if (isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final thMonths = [
        '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
      ];
      final enMonths = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      if (isThai) {
        return '${dt.day} ${thMonths[dt.month]} ${dt.year + 543}';
      }
      return '${dt.day} ${enMonths[dt.month]} ${dt.year}';
    } catch (_) {
      return isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _urgencyLabel(String urgency, bool isThai) {
    switch (urgency) {
      case 'urgent':
        return isThai ? 'เร่งด่วน' : 'Urgent';
      case 'scheduled':
        return isThai ? 'ตามกำหนด' : 'Scheduled';
      default:
        return isThai ? 'ปกติ' : 'Normal';
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'urgent':
        return AppColors.danger;
      case 'scheduled':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

}

class _DetailLine {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});
}
