import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../../services/language_service.dart';
import '../../../l10n/app_strings.dart';
import '../../notification_screen.dart';
import '../../role_selection_screen.dart';
import '../active_job_screen.dart';

class GuardHomeTab extends StatefulWidget {
  final void Function(int)? onSwitchTab;

  const GuardHomeTab({super.key, this.onSwitchTab});

  @override
  State<GuardHomeTab> createState() => _GuardHomeTabState();
}

class _GuardHomeTabState extends State<GuardHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchDashboard();
      context.read<BookingProvider>().fetchActiveJob();
      context.read<NotificationProvider>().fetchUnreadCount(role: 'guard');
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<BookingProvider>().fetchDashboard(),
      context.read<BookingProvider>().fetchActiveJob(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardHomeStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
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
                      const SizedBox(height: 16),
                      _buildActiveJobBanner(isThai),
                      const SizedBox(height: 16),
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
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationScreen(isGuard: true),
          ),
        );
        if (mounted) {
          context.read<NotificationProvider>().fetchUnreadCount(role: 'guard');
        }
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GuardHomeStrings strings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
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
                  'PGuard',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${strings.greeting}, ${context.watch<AuthProvider>().fullName ?? strings.sampleGuardName}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationBell(),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(GuardHomeStrings strings) {
    final tracking = context.watch<TrackingProvider>();
    final booking = context.watch<BookingProvider>();
    final isOnline = tracking.isOnline;
    final isConnecting = tracking.isConnecting;
    final hasActiveJob = booking.activeJob != null;

    // Status label
    String statusText;
    Color dotColor;
    if (isConnecting) {
      statusText = strings.connecting;
      dotColor = AppColors.warning;
    } else if (hasActiveJob && isOnline) {
      statusText = strings.busy;
      dotColor = const Color(0xFFF59E0B);
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
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isOnline || isConnecting,
                activeTrackColor: hasActiveJob ? const Color(0xFFF59E0B) : AppColors.primary,
                onChanged: (isConnecting || hasActiveJob)
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

  Widget _buildActiveJobBanner(bool isThai) {
    final dashboard = context.watch<BookingProvider>().dashboard;
    final activeJob = dashboard?['active_job'] as Map<String, dynamic>?;

    // Only show if there's an active job with started_at (guard started working)
    if (activeJob == null || activeJob['started_at'] == null) {
      return const SizedBox.shrink();
    }

    final customerName = activeJob['customer_name'] as String? ?? '-';
    final assignmentId = activeJob['assignment_id'] as String? ?? '';

    return GestureDetector(
      onTap: () async {
        final result = await context
            .read<BookingProvider>()
            .fetchActiveJobData();
        if (!mounted || result == null) return;

        final remaining =
            (result['remaining_seconds'] as num?)?.toInt() ?? 0;
        final bookedHours =
            (result['booked_hours'] as num?)?.toInt() ?? 6;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveJobScreen(
              assignmentId: assignmentId,
              customerName: result['customer_name'] as String?,
              address: result['address'] as String?,
              bookedHours: bookedHours,
              remainingSeconds: remaining,
              startedAt: result['started_at'] as String?,
            ),
          ),
        ).then((_) {
          if (!mounted) return;
          context.read<BookingProvider>().fetchDashboard();
          context.read<BookingProvider>().fetchActiveJob();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.timer_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isThai ? 'กำลังดำเนินงาน' : 'Job In Progress',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customerName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isThai ? 'ดูเวลา' : 'View',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
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
    final isThai = LanguageProvider.of(context).isThai;
    final isOnline = context.watch<TrackingProvider>().isOnline;
    final dashboard = context.watch<BookingProvider>().dashboard;
    final pendingAcceptance =
        (dashboard?['pending_acceptance_count'] as num?) ?? 0;
    final pendingJobs = (dashboard?['pending_jobs_count'] as num?) ?? 0;
    final totalPending = pendingAcceptance.toInt() + pendingJobs.toInt();
    final hasPendingJobs = totalPending > 0;

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
                ? (pendingAcceptance > 0
                    ? (isThai
                        ? 'มีงานใหม่รอการตอบรับ ${pendingAcceptance.toInt()} รายการ!'
                        : '${pendingAcceptance.toInt()} new job(s) waiting for your response!')
                    : (hasPendingJobs
                        ? strings.newJobsCount(totalPending)
                        : strings.noNewJobsMsg))
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
              onPressed: () => widget.onSwitchTab?.call(1),
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
