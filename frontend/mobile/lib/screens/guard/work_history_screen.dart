import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import '../../providers/booking_provider.dart';

class WorkHistoryScreen extends StatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  State<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends State<WorkHistoryScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<BookingProvider>().fetchWorkHistory();
    });
  }

  /// Map tab index to API status filter.
  String? _statusForTab(int index) {
    switch (index) {
      case 1:
        return 'ongoing'; // assigned, en_route, arrived
      case 2:
        return 'completed';
      case 3:
        return 'cancelled';
      default:
        return null; // all
    }
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTabIndex = index);
    context.read<BookingProvider>().fetchWorkHistory(status: _statusForTab(index));
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = WorkHistoryStrings(isThai: isThai);
    final provider = context.watch<BookingProvider>();

    final tabs = [
      isThai ? 'ทั้งหมด' : 'All',
      isThai ? 'กำลังดำเนินการ' : 'Ongoing',
      isThai ? 'เสร็จสิ้น' : 'Completed',
      isThai ? 'ยกเลิก' : 'Cancelled',
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          strings.appBarTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.deepBlue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onTabChanged(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tabs[index],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.deepBlue
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(strings, provider.workHistory),
                        const SizedBox(height: 24),
                        Text(
                          strings.jobHistory,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._buildJobsList(strings, provider.workHistory),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildJobsList(
    WorkHistoryStrings strings,
    Map<String, dynamic>? workHistory,
  ) {
    final jobs = (workHistory?['jobs'] as List<dynamic>?) ?? [];

    if (jobs.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Icon(
                  Icons.work_history_rounded,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  LanguageProvider.of(context).isThai
                      ? 'ไม่มีรายการ'
                      : 'No jobs found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return jobs.map<Widget>((job) {
      final j = job as Map<String, dynamic>;
      final status = j['assignment_status'] as String? ?? '';
      final statusLabel = _localizedStatus(status);
      final statusColor = _statusColor(status);

      final durationMin = (j['duration_minutes'] as num?)?.toInt();
      final durationStr = durationMin != null
          ? '${(durationMin / 60).floor()} ${LanguageProvider.of(context).isThai ? "ชม." : "hrs"} ${durationMin % 60} ${LanguageProvider.of(context).isThai ? "นาที" : "min"}'
          : '-';

      final price = j['offered_price'] as num?;
      final priceStr = price != null ? '฿${price.toStringAsFixed(0)}' : '-';

      final rating = (j['rating'] as num?)?.toDouble();

      final createdAt = j['created_at'] as String? ?? '';
      final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

      return _buildJobCard(
        client: j['customer_name'] as String? ?? '-',
        location: j['address'] as String? ?? '-',
        date: dateStr,
        duration: durationStr,
        earning: priceStr,
        rating: rating,
        statusLabel: statusLabel,
        statusColor: statusColor,
      );
    }).toList();
  }

  String _localizedStatus(String status) {
    final isThai = LanguageProvider.of(context).isThai;
    switch (status) {
      case 'assigned':
        return isThai ? 'ได้รับมอบหมาย' : 'Assigned';
      case 'en_route':
        return isThai ? 'กำลังเดินทาง' : 'En Route';
      case 'arrived':
        return isThai ? 'ถึงแล้ว' : 'Arrived';
      case 'completed':
        return isThai ? 'เสร็จสิ้น' : 'Completed';
      case 'cancelled':
        return isThai ? 'ยกเลิก' : 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      case 'en_route':
      case 'arrived':
        return AppColors.info;
      case 'assigned':
        return Colors.amber.shade700;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildSummaryCards(
    WorkHistoryStrings strings,
    Map<String, dynamic>? workHistory,
  ) {
    final totalJobs = (workHistory?['total_jobs'] as num?)?.toInt() ?? 0;
    final totalHours = (workHistory?['total_hours'] as num?)?.toDouble() ?? 0;
    final avgRating = (workHistory?['avg_rating'] as num?)?.toDouble();

    return Row(
      children: [
        _buildSummaryItem(
          strings.totalJobs,
          '$totalJobs',
          Icons.work_outline_rounded,
          AppColors.info,
        ),
        const SizedBox(width: 12),
        _buildSummaryItem(
          strings.totalHours,
          totalHours.toStringAsFixed(0),
          Icons.access_time_rounded,
          AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildSummaryItem(
          strings.avgRating,
          avgRating != null ? avgRating.toStringAsFixed(1) : '-',
          Icons.star_rounded,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard({
    required String client,
    required String location,
    required String date,
    required String duration,
    required String earning,
    required double? rating,
    required String statusLabel,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildJobDetail(Icons.calendar_today_outlined, date),
              _buildJobDetail(Icons.access_time_rounded, duration),
              if (rating != null)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              Text(
                earning,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
