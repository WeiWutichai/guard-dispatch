import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'withdrawal_approval_screen.dart';
import 'chat_list_screen.dart';
import 'call_screen.dart';
import 'notification_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = DashboardStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactOptions(context, isThai),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, strings),
              const SizedBox(height: 24),
              _buildKPIGrid(strings),
              const SizedBox(height: 24),
              _buildRevenueChart(isThai, strings),
              const SizedBox(height: 24),
              _buildBankSummary(strings),
              const SizedBox(height: 24),
              _buildWithdrawalList(context, strings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashboardStrings strings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.headerTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  strings.headerSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationScreen(isGuard: true),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid(DashboardStrings strings) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          strings.totalRevenue,
          '฿1,240,500',
          strings.kpiSubFees,
          Icons.account_balance_wallet_outlined,
        ),
        _buildKPICard(
          strings.pending,
          '฿45,200',
          strings.kpiSubItems,
          Icons.pending_actions_outlined,
        ),
        _buildKPICard(
          strings.totalFees,
          '฿18,900',
          strings.kpiSubPending,
          Icons.receipt_long_outlined,
        ),
        _buildKPICard(
          strings.netProfit,
          '฿1,176,400',
          strings.kpiSubVerified,
          Icons.auto_graph_outlined,
          isSuccess: true,
        ),
      ],
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    String subValue,
    IconData icon, {
    bool isSuccess = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              if (isSuccess)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 16,
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subValue,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isSuccess ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(bool isThai, DashboardStrings strings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.chartTitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildChartLegend(strings.chartRevenue, AppColors.primary),
                  const SizedBox(width: 12),
                  _buildChartLegend(
                    strings.chartWithdrawals,
                    AppColors.disabled,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(0.4, 0.2),
                _buildBar(0.6, 0.3),
                _buildBar(0.5, 0.4),
                _buildBar(0.8, 0.5),
                _buildBar(0.7, 0.4),
                _buildBar(0.9, 0.6),
                _buildBar(0.6, 0.3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                [
                      strings.sampleDate1,
                      '10 ${isThai ? 'ม.ค.' : 'Jan'}',
                      '20 ${isThai ? 'ม.ค.' : 'Jan'}',
                      '30 ${isThai ? 'ม.ค.' : 'Jan'}',
                    ]
                    .map<Widget>(
                      (e) => Text(
                        e.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBar(double h1, double h2) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 100 * h1,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100 * h2,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankSummary(DashboardStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.bankSummaryTitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildBankChip(strings.bankKBank, '฿245,600', AppColors.success),
            const SizedBox(width: 12),
            _buildBankChip(strings.bankSCB, '฿180,200', AppColors.info),
          ],
        ),
      ],
    );
  }

  Widget _buildBankChip(String name, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'KB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalList(BuildContext context, DashboardStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.withdrawalListTitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              strings.viewAll,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildWithdrawalItem(
          context,
          'นายสมชาย รักชาติ',
          '${strings.bankKBank} • XXX-X-X1234-X',
          '฿12,400.00',
          strings.statusPending,
        ),
        _buildWithdrawalItem(
          context,
          'นายวิชัย นามสมมุติ',
          '${strings.bankSCB} • XXX-X-X5678-X',
          '฿8,900.00',
          strings.statusProcessing,
          isProcessing: true,
        ),
        _buildWithdrawalItem(
          context,
          'นางสาวมานี มีทรัพย์',
          '${LanguageProvider.of(context).isThai ? 'กรุงเทพ' : 'Bangkok Bank'} • XXX-X-X9911-X',
          '฿15,200.00',
          strings.statusCompleted,
          isCompleted: true,
        ),
      ],
    );
  }

  Widget _buildWithdrawalItem(
    BuildContext context,
    String name,
    String subtitle,
    String amount,
    String status, {
    bool isProcessing = false,
    bool isCompleted = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WithdrawalApprovalScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.person_outline, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.1)
                        : (isProcessing
                              ? AppColors.info.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? AppColors.success
                          : (isProcessing ? AppColors.info : AppColors.warning),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context, bool isThai) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isThai ? 'ติดต่อเจ้าหน้าที่' : 'Contact Guard',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildContactAction(
                      context: context,
                      icon: Icons.call_rounded,
                      label: isThai ? 'โทรหา' : 'Call',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              userName: isThai
                                  ? 'เจ้าหน้าที่สมชาย'
                                  : 'Guard Somchai',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildContactAction(
                      context: context,
                      icon: Icons.chat_bubble_rounded,
                      label: isThai ? 'แชท' : 'Chat',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
