import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class WorkHistoryScreen extends StatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  State<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends State<WorkHistoryScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = WorkHistoryStrings(isThai: isThai);

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
                      onTap: () => setState(() => _selectedTabIndex = index),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(strings),
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
                  ..._buildFilteredJobs(strings),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredJobs(WorkHistoryStrings strings) {
    // Dummy data with type
    final allJobs = [
      _JobData(
        client: strings.sampleJob1Client,
        location: strings.sampleJob1Location,
        date: strings.sampleJob1Date,
        duration: strings.sampleJob1Duration,
        earning: '฿800',
        rating: 5.0,
        statusLabel: strings.completed,
        type: 2, // Completed
      ),
      _JobData(
        client: strings.sampleJob2Client,
        location: strings.sampleJob2Location,
        date: strings.sampleJob2Date,
        duration: strings.sampleJob2Duration,
        earning: '฿1,600',
        rating: 4.5,
        statusLabel: strings.completed,
        type: 2, // Completed
      ),
      _JobData(
        client: strings.sampleJob3Client,
        location: strings.sampleJob3Location,
        date: strings.sampleJob3Date,
        duration: strings.sampleJob3Duration,
        earning: '฿1,200',
        rating: 5.0,
        statusLabel: strings.completed,
        type: 2, // Completed
      ),
      _JobData(
        client: strings.sampleJob4Client,
        location: strings.sampleJob4Location,
        date: strings.sampleJob4Date,
        duration: strings.sampleJob4Duration,
        earning: '฿1,000',
        rating: 4.0,
        statusLabel: strings.completed,
        type: 2, // Completed
      ),
    ];

    final filtered = _selectedTabIndex == 0
        ? allJobs
        : allJobs.where((job) => job.type == _selectedTabIndex).toList();

    if (filtered.isEmpty) {
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

    return filtered.map((job) {
      return _buildJobCard(
        client: job.client,
        location: job.location,
        date: job.date,
        duration: job.duration,
        earning: job.earning,
        rating: job.rating,
        statusLabel: job.statusLabel,
      );
    }).toList();
  }

  Widget _buildSummaryCards(WorkHistoryStrings strings) {
    return Row(
      children: [
        _buildSummaryItem(
          strings.totalJobs,
          '156',
          Icons.work_outline_rounded,
          AppColors.info,
        ),
        const SizedBox(width: 12),
        _buildSummaryItem(
          strings.totalHours,
          '624',
          Icons.access_time_rounded,
          AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildSummaryItem(
          strings.avgRating,
          '4.8',
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
    required double rating,
    required String statusLabel,
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
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
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
              ),
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

class _JobData {
  final String client;
  final String location;
  final String date;
  final String duration;
  final String earning;
  final double rating;
  final String statusLabel;
  final int type; // 1: In progress, 2: Completed, 3: Cancelled

  _JobData({
    required this.client,
    required this.location,
    required this.date,
    required this.duration,
    required this.earning,
    required this.rating,
    required this.statusLabel,
    required this.type,
  });
}
