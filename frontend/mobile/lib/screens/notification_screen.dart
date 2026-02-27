import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';

class NotificationScreen extends StatelessWidget {
  final bool isGuard;
  const NotificationScreen({super.key, this.isGuard = false});

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = NotificationStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          s.appBarTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: ListView(
        children: isGuard
            ? _buildGuardNotifications(s)
            : _buildHirerNotifications(s),
      ),
    );
  }

  List<Widget> _buildGuardNotifications(NotificationStrings s) {
    return [
      _buildNotificationItem(
        icon: Icons.work_outline_rounded,
        color: AppColors.primary,
        title: s.guardNewJobTitle,
        message: s.guardNewJobMsg,
        time: s.guardNewJobTime,
        isUnread: true,
      ),
      _buildNotificationItem(
        icon: Icons.payments_outlined,
        color: AppColors.success,
        title: s.guardPaymentTitle,
        message: s.guardPaymentMsg,
        time: s.guardPaymentTime,
        isUnread: true,
      ),
      _buildNotificationItem(
        icon: Icons.stars_rounded,
        color: AppColors.warning,
        title: s.guardReviewTitle,
        message: s.guardReviewMsg,
        time: s.guardReviewTime,
      ),
    ];
  }

  List<Widget> _buildHirerNotifications(NotificationStrings s) {
    return [
      _buildNotificationItem(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        title: s.hirerBookingTitle,
        message: s.hirerBookingMsg,
        time: s.hirerBookingTime,
        isUnread: true,
      ),
      _buildNotificationItem(
        icon: Icons.chat_bubble_rounded,
        color: AppColors.info,
        title: s.hirerMessageTitle,
        message: s.hirerMessageMsg,
        time: s.hirerMessageTime,
        isUnread: true,
      ),
      _buildNotificationItem(
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.primary,
        title: s.hirerPaymentTitle,
        message: s.hirerPaymentMsg,
        time: s.hirerPaymentTime,
      ),
    ];
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String time,
    bool isUnread = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? color.withValues(alpha: 0.05) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (isUnread)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
