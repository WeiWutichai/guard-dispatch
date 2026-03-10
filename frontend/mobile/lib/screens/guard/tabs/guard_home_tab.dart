import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../services/language_service.dart';
import '../../../l10n/app_strings.dart';
import '../../role_selection_screen.dart';

class GuardHomeTab extends StatefulWidget {
  const GuardHomeTab({super.key});

  @override
  State<GuardHomeTab> createState() => _GuardHomeTabState();
}

class _GuardHomeTabState extends State<GuardHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchDashboard();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<BookingProvider>().fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardHomeStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(strings),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusToggle(strings),
                      const SizedBox(height: 24),
                      _buildStatsGrid(strings),
                      const SizedBox(height: 24),
                      _buildAlertCard(strings),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GuardHomeStrings strings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final phone = context.read<AuthProvider>().phone;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleSelectionScreen(phone: phone),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.greeting,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    context.watch<AuthProvider>().fullName ?? strings.sampleGuardName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(GuardHomeStrings strings) {
    final tracking = context.watch<TrackingProvider>();
    final isOnline = tracking.isOnline;
    final isConnecting = tracking.isConnecting;

    // Status label
    String statusText;
    Color dotColor;
    if (isConnecting) {
      statusText = strings.connecting;
      dotColor = AppColors.warning;
    } else if (isOnline) {
      statusText = strings.ready;
      dotColor = AppColors.success;
    } else {
      statusText = strings.notReady;
      dotColor = AppColors.danger;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: isOnline || isConnecting,
                activeTrackColor: AppColors.primary,
                onChanged: isConnecting
                    ? null
                    : (_) => context.read<TrackingProvider>().toggle(),
              ),
            ],
          ),
        ),
        // GPS accuracy indicator when online
        if (isOnline && tracking.lastPosition != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '${strings.gpsAccuracy}: ${tracking.lastPosition!.accuracy.toStringAsFixed(0)}m',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        // Error message
        if (tracking.error != null && tracking.error!.contains('permission'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              strings.locationPermissionDenied,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
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

  Widget _buildStatsGrid(GuardHomeStrings strings) {
    final dashboard = context.watch<BookingProvider>().dashboard;
    final todayEarnings = (dashboard?['today_earnings'] as num?) ?? 0;
    final weekEarnings = (dashboard?['week_earnings'] as num?) ?? 0;
    final lastWeekEarnings = (dashboard?['last_week_earnings'] as num?) ?? 0;
    final todayJobs = (dashboard?['today_jobs_count'] as num?) ?? 0;

    // Calculate week-over-week change
    double weekChange = 0;
    if (lastWeekEarnings > 0) {
      weekChange = ((weekEarnings - lastWeekEarnings) / lastWeekEarnings * 100).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              strings.today,
              _formatCurrency(todayEarnings),
              strings.completedJobsCount(todayJobs.toInt()),
              Icons.today_rounded,
              AppColors.info,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              strings.thisWeek,
              _formatCurrency(weekEarnings),
              strings.weekChangePercent(weekChange),
              Icons.analytics_rounded,
              AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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

  Widget _buildAlertCard(GuardHomeStrings strings) {
    final isOnline = context.watch<TrackingProvider>().isOnline;
    final dashboard = context.watch<BookingProvider>().dashboard;
    final pendingJobs = (dashboard?['pending_jobs_count'] as num?) ?? 0;
    final hasPendingJobs = pendingJobs > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOnline
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.disabled.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: isOnline ? AppColors.primary : AppColors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOnline ? strings.incomingJobs : strings.unavailable,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOnline
                ? (hasPendingJobs
                    ? strings.newJobsCount(pendingJobs.toInt())
                    : strings.noNewJobsMsg)
                : strings.setAvailableMsg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (isOnline && hasPendingJobs) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                strings.viewNewJobs,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
