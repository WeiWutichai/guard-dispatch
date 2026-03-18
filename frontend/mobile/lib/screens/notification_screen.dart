import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import '../providers/notification_provider.dart';
import '../providers/booking_provider.dart';
import 'hirer/hirer_history_screen.dart';
import 'guard/guard_job_detail_screen.dart';
import 'guard/work_history_screen.dart';
import 'guard/ratings_reviews_screen.dart';
import 'chat_list_screen.dart';

class NotificationScreen extends StatefulWidget {
  final bool isGuard;
  const NotificationScreen({super.key, this.isGuard = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String get _role => widget.isGuard ? 'guard' : 'customer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications(role: _role);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = NotificationStrings(isThai: isThai);
    final provider = context.watch<NotificationProvider>();

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
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllAsRead(role: _role),
              child: Text(
                s.readAll,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _buildBody(provider, s, isThai),
    );
  }

  Widget _buildBody(NotificationProvider provider, NotificationStrings s, bool isThai) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(s.loadError, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              s.emptyTitle,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              s.emptySubtitle,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchNotifications(role: _role),
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: provider.notifications.length,
        itemBuilder: (context, index) {
          final n = provider.notifications[index];
          return _buildNotificationItem(n, isThai, provider);
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    Map<String, dynamic> notification,
    bool isThai,
    NotificationProvider provider,
  ) {
    final type = notification['notification_type'] as String? ?? 'system';
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['is_read'] as bool? ?? true;
    final sentAt = notification['sent_at'] as String? ?? '';
    final id = notification['id'] as String? ?? '';

    final style = _getNotificationStyle(type);
    final timeStr = _formatRelativeTime(sentAt, isThai);

    return GestureDetector(
      onTap: () {
        if (!isRead && id.isNotEmpty) {
          provider.markAsRead(id);
        }
        _onNotificationTap(notification);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.transparent : style.color.withValues(alpha: 0.05),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isRead)
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
      ),
    );
  }

  void _onNotificationTap(Map<String, dynamic> notification) {
    final type = notification['notification_type'] as String? ?? 'system';
    final payload = notification['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : <String, dynamic>{};

    if (widget.isGuard) {
      _handleGuardNavigation(type, payloadMap);
    } else {
      _handleCustomerNavigation(type);
    }
  }

  void _handleCustomerNavigation(String type) {
    switch (type) {
      case 'chat_message':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatListScreen(actingRole: 'customer'),
          ),
        );
      case 'booking_created':
      case 'guard_assigned':
      case 'guard_en_route':
      case 'guard_arrived':
      case 'booking_completed':
      case 'booking_cancelled':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HirerHistoryScreen(),
          ),
        );
      default:
        break;
    }
  }

  Future<void> _handleGuardNavigation(
    String type,
    Map<String, dynamic> payload,
  ) async {
    switch (type) {
      case 'chat_message':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatListScreen(actingRole: 'guard'),
          ),
        );
      case 'guard_assigned':
      case 'booking_created':
        // Try to find the matching job and navigate to detail
        final requestId = payload['request_id'] as String?;
        if (requestId == null) return;
        try {
          final booking = context.read<BookingProvider>();
          final allJobs = await booking.fetchJobsAndReturn();
          if (!mounted) return;
          final match = allJobs.where((j) {
            return j['request_id']?.toString() == requestId;
          });
          if (match.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardJobDetailScreen(job: match.first),
              ),
            );
          }
        } catch (_) {}
      case 'booking_completed':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WorkHistoryScreen(),
          ),
        );
      case 'system':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RatingsReviewsScreen(),
          ),
        );
      default:
        break;
    }
  }

  ({IconData icon, Color color}) _getNotificationStyle(String type) {
    return switch (type) {
      'booking_created' => (icon: Icons.check_circle_rounded, color: AppColors.success),
      'guard_assigned' => (icon: Icons.work_outline_rounded, color: AppColors.info),
      'guard_en_route' => (icon: Icons.directions_car_rounded, color: AppColors.info),
      'guard_arrived' => (icon: Icons.location_on_rounded, color: AppColors.success),
      'booking_completed' => (icon: Icons.verified_rounded, color: AppColors.success),
      'booking_cancelled' => (icon: Icons.cancel_rounded, color: const Color(0xFFEF4444)),
      'chat_message' => (icon: Icons.chat_bubble_rounded, color: AppColors.info),
      _ => (icon: Icons.info_outline_rounded, color: AppColors.textSecondary),
    };
  }

  String _formatRelativeTime(String sentAt, bool isThai) {
    if (sentAt.isEmpty) return '';
    final s = NotificationStrings(isThai: isThai);
    try {
      final dt = DateTime.parse(sentAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return s.justNow;
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${s.minutesAgo}';
      if (diff.inHours < 24) return '${diff.inHours} ${s.hoursAgo}';
      if (diff.inDays < 7) return '${diff.inDays} ${s.daysAgo}';
      return '${diff.inDays ~/ 7} ${s.weeksAgo}';
    } catch (_) {
      return '';
    }
  }
}
