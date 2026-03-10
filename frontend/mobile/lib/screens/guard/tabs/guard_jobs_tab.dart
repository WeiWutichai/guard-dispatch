import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../providers/booking_provider.dart';
import '../../../services/language_service.dart';
import '../../../l10n/app_strings.dart';

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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            strings.appBarTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: '${strings.currentTabLabel} (${booking.currentJobs.length})'),
              Tab(text: '${strings.completedTabLabel} (${booking.completedJobs.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCurrentJobs(strings, isThai),
            _buildCompletedJobs(strings, isThai),
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
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: index < jobs.length - 1 ? 16 : 0),
          child: _buildJobCard(jobs[index], strings, isThai),
        ),
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
            padding: EdgeInsets.only(bottom: index < jobs.length - 1 ? 12 : 0),
            child: _buildCompletedJobItem(
              job['customer_name'] as String? ?? '-',
              job['completed_at'] as String? ?? '',
              _formatCurrency(job['offered_price']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, GuardJobsStrings strings, bool isThai) {
    final customerName = job['customer_name'] as String? ?? '-';
    final address = job['address'] as String? ?? '-';
    final price = _formatCurrency(job['offered_price']);
    final description = job['description'] as String? ?? '';
    final specialInstructions = job['special_instructions'] as String?;
    final assignmentStatus = job['assignment_status'] as String? ?? 'assigned';

    final statusLabel = _getStatusLabel(assignmentStatus, isThai);
    final statusColor = _getStatusColor(assignmentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 8),
                    const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          Text(
            customerName,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            ),
          ],
          if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              isThai ? 'คำสั่งพิเศษ' : 'Special Instructions',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              specialInstructions,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          if (assignmentStatus == 'assigned' || assignmentStatus == 'en_route') ...[
            const SizedBox(height: 20),
            _buildStatusActionButton(job, isThai),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusActionButton(Map<String, dynamic> job, bool isThai) {
    final assignmentId = job['assignment_id'] as String? ?? '';
    final status = job['assignment_status'] as String? ?? 'assigned';

    String buttonLabel;
    String nextStatus;
    if (status == 'assigned') {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      nextStatus = 'en_route';
    } else {
      buttonLabel = isThai ? 'ถึงจุดหมาย' : 'Arrived';
      nextStatus = 'arrived';
    }

    return ElevatedButton(
      onPressed: () {
        context.read<BookingProvider>().updateAssignmentStatus(assignmentId, nextStatus);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        buttonLabel,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getStatusLabel(String status, bool isThai) {
    switch (status) {
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

  Color _getStatusColor(String status) {
    switch (status) {
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

  Widget _buildCompletedJobItem(String client, String date, String amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
