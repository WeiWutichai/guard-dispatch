import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../providers/booking_provider.dart';
import '../../../services/language_service.dart';
import '../../../l10n/app_strings.dart';

class GuardIncomeTab extends StatefulWidget {
  const GuardIncomeTab({super.key});

  @override
  State<GuardIncomeTab> createState() => _GuardIncomeTabState();
}

class _GuardIncomeTabState extends State<GuardIncomeTab> {
  int _activeSubTab = 0; // 0: Income, 1: Bonus, 2: Wallet

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardIncomeStrings(isThai: isThai);

    return Scaffold(
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
                            'P-Guard',
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
                _buildSubTabNavigation(strings),
              ],
            ),
          ),
          Expanded(
            child: _buildActiveContent(strings, isThai),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
    if (value >= 1000) {
      final formatted = value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return '฿$formatted';
    }
    return '฿${value.toStringAsFixed(0)}';
  }

  Widget _buildSubTabNavigation(GuardIncomeStrings strings) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSubTabItem(0, strings.tabIncomeGoals),
          const SizedBox(width: 8),
          _buildSubTabItem(1, strings.tabBonusPoints),
          const SizedBox(width: 8),
          _buildSubTabItem(2, strings.tabWallet),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(int index, String label) {
    bool isActive = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveContent(GuardIncomeStrings strings, bool isThai) {
    switch (_activeSubTab) {
      case 0:
        return _buildIncomeContent(strings, isThai);
      case 1:
        return _buildComingSoon(isThai ? 'โบนัสและแต้ม' : 'Bonus & Points', isThai);
      case 2:
        return _buildWalletContent(strings, isThai);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIncomeContent(GuardIncomeStrings strings, bool isThai) {
    final provider = context.watch<BookingProvider>();
    final earnings = provider.earnings;

    if (provider.isLoading && earnings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final monthEarnings = (earnings?['month_earnings'] as num?) ?? 0;
    final weekEarnings = (earnings?['week_earnings'] as num?) ?? 0;
    final completedCount = (earnings?['completed_jobs_count'] as num?) ?? 0;
    final dailyBreakdown = (earnings?['daily_breakdown'] as List<dynamic>?) ?? [];

    final avgPerJob = completedCount > 0 ? monthEarnings / completedCount : 0;

    return RefreshIndicator(
      onRefresh: () => context.read<BookingProvider>().fetchEarnings(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(strings.trackIncome),
            const SizedBox(height: 16),
            _buildMonthlyCard(strings, monthEarnings, completedCount),
            const SizedBox(height: 24),
            _buildWeeklyStatsCard(strings, weekEarnings, avgPerJob, completedCount),
            const SizedBox(height: 24),
            _buildSectionHeader(strings.dailyIncome),
            const SizedBox(height: 12),
            if (dailyBreakdown.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    isThai ? 'ยังไม่มีข้อมูลรายวัน' : 'No daily data yet',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...dailyBreakdown.map((day) {
                final date = day['date'] as String? ?? '';
                final amount = (day['amount'] as num?) ?? 0;
                final jobsCount = (day['jobs_count'] as num?) ?? 0;
                return _buildDailyIncomeItem(
                  date,
                  _formatCurrency(amount),
                  '$jobsCount ${isThai ? "งาน" : "jobs"}',
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCard(GuardIncomeStrings strings, num monthEarnings, num completedCount) {
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
          Text(
            strings.monthlyGoal,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(monthEarnings),
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedCount ${strings.completedThisMonth}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStatsCard(GuardIncomeStrings strings, num weekEarnings, num avgPerJob, num completedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                strings.thisWeek,
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatCurrency(weekEarnings),
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCompactStat(strings.avgPerJob, _formatCurrency(avgPerJob)),
              const SizedBox(width: 24),
              _buildCompactStat(strings.jobCount, '$completedCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDailyIncomeItem(String date, String amount, String jobs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              Text(jobs, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Text(
            amount,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent(GuardIncomeStrings strings, bool isThai) {
    final earnings = context.watch<BookingProvider>().earnings;
    final totalEarned = (earnings?['total_earned'] as num?) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(strings.walletTitle),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThai ? 'รายได้รวมทั้งหมด' : 'Total Earned',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(totalEarned),
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildComingSoonCard(
            isThai ? 'ระบบถอนเงิน' : 'Withdrawal System',
            isThai ? 'ฟีเจอร์ถอนเงินจะเปิดให้บริการเร็วๆ นี้' : 'Withdrawal feature coming soon',
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon(String title, bool isThai) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isThai ? 'เร็วๆ นี้' : 'Coming Soon',
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.construction_rounded, color: AppColors.warning, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
