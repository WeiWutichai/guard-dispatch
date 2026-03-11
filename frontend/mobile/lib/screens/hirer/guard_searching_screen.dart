import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';

class GuardSearchingScreen extends StatefulWidget {
  final String? requestId;
  final double lat;
  final double lng;

  const GuardSearchingScreen({
    super.key,
    this.requestId,
    required this.lat,
    required this.lng,
  });

  @override
  State<GuardSearchingScreen> createState() => _GuardSearchingScreenState();
}

class _GuardSearchingScreenState extends State<GuardSearchingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnim;

  bool _showGuardList = false;
  bool _isAssigning = false;
  String? _assigningGuardId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _fetchGuards();
    });
  }

  Future<void> _fetchGuards() async {
    await context.read<BookingProvider>().fetchAvailableGuards(
          widget.lat,
          widget.lng,
        );
    if (mounted) {
      setState(() => _showGuardList = true);
    }
  }

  Future<void> _assignGuard(String guardId) async {
    if (widget.requestId == null) return;
    final isThai = LanguageProvider.of(context).isThai;

    setState(() {
      _isAssigning = true;
      _assigningGuardId = guardId;
    });
    try {
      await context.read<BookingProvider>().assignGuardToRequest(
            widget.requestId!,
            guardId,
          );
      if (!mounted) return;
      // Show success bottom sheet then pop
      _showSuccessSheet(isThai);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'เกิดข้อผิดพลาด: $e' : 'Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
          _assigningGuardId = null;
        });
      }
    }
  }

  void _showSuccessSheet(bool isThai) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              isThai ? 'จับคู่สำเร็จ!' : 'Guard Assigned!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isThai
                  ? 'เจ้าหน้าที่ รปภ. กำลังเดินทางมาหาคุณ'
                  : 'Your security guard is on the way',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isThai ? 'กลับหน้าหลัก' : 'Back to Home',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final provider = context.watch<BookingProvider>();

    if (!_showGuardList || provider.isLoadingGuards) {
      return _buildRadarView(isThai);
    }

    return _buildGuardListView(isThai, provider);
  }

  // ===========================================================================
  // Phase 1: Radar animation
  // ===========================================================================

  Widget _buildRadarView(bool isThai) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            SizedBox(
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _rotateController]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarPainter(
                      pulse: _pulseAnim.value,
                      rotation: _rotateController.value * 2 * pi,
                    ),
                    child: child,
                  );
                },
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isThai ? 'กำลังค้นหาเจ้าหน้าที่' : 'Searching for Guards',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                isThai
                    ? 'ระบบกำลังจับคู่เจ้าหน้าที่ รปภ.\nที่เหมาะสมกับคำขอของคุณ'
                    : 'We are matching the best\nsecurity guards for your request',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _DotsIndicator(),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Phase 2: Guard list
  // ===========================================================================

  Widget _buildGuardListView(bool isThai, BookingProvider provider) {
    final guards = provider.availableGuards;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Column(
        children: [
          // Green gradient header
          _buildGradientHeader(isThai, guards.length),

          // Guard list
          Expanded(
            child: guards.isEmpty
                ? _buildEmptyState(isThai)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: guards.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildGuardCard(guards[index], isThai),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(bool isThai, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
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
                      'SecureGuard',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isThai
                          ? 'บริการรักษาความปลอดภัย'
                          : 'Security Services',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _showGuardList = false);
                  _fetchGuards();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            isThai
                ? 'พบเจ้าหน้าที่ $count คนในพื้นที่ใกล้เคียง'
                : 'Found $count guards near your area',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardCard(Map<String, dynamic> guard, bool isThai) {
    final name = guard['full_name'] as String? ?? '-';
    final distanceKm = (guard['distance_km'] as num?)?.toDouble() ?? 0;
    final experienceYears = guard['experience_years'] as int? ?? 0;
    final completedJobs = (guard['completed_jobs'] as num?)?.toInt() ?? 0;
    final rating = (guard['rating'] as num?)?.toDouble() ?? 4.5;
    final reviewCount = (guard['review_count'] as num?)?.toInt() ?? 0;
    final lastSeenAt = guard['last_seen_at'] as String?;
    final guardId = guard['id'] as String? ?? '';

    int minutesAgo = 0;
    if (lastSeenAt != null) {
      final dt = DateTime.tryParse(lastSeenAt);
      if (dt != null) {
        minutesAgo = DateTime.now().toUtc().difference(dt).inMinutes;
      }
    }

    final isOnlineNow = minutesAgo <= 5;
    final isAssigningThis = _isAssigning && _assigningGuardId == guardId;

    // Badge based on completed jobs
    String badgeText;
    Color badgeBg;
    Color badgeText_;
    IconData badgeIcon;
    if (completedJobs >= 50) {
      badgeText = isThai ? 'เจ้าหน้าที่ยอดนิยม' : 'Top Guard';
      badgeBg = const Color(0xFFFEF3C7);
      badgeText_ = const Color(0xFFB45309);
      badgeIcon = Icons.star_rounded;
    } else if (completedJobs >= 20) {
      badgeText = isThai ? 'มีประสบการณ์' : 'Experienced';
      badgeBg = const Color(0xFFDBEAFE);
      badgeText_ = const Color(0xFF1D4ED8);
      badgeIcon = Icons.verified_rounded;
    } else {
      badgeText = isThai ? 'ว่าง' : 'Available';
      badgeBg = const Color(0xFFF0FDF4);
      badgeText_ = AppColors.primary;
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnlineNow
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: guard['avatar_url'] != null
                          ? ClipOval(
                              child: Image.network(
                                guard['avatar_url'],
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                errorBuilder: (_, _, _) => const Icon(
                                    Icons.person_rounded,
                                    size: 28,
                                    color: AppColors.primary),
                              ),
                            )
                          : const Icon(Icons.person_rounded,
                              size: 28, color: AppColors.primary),
                    ),
                    // Online dot
                    if (isOnlineNow)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Name + badge + rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: badgeText_),
                            const SizedBox(width: 4),
                            Text(
                              badgeText,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeText_,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Distance pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} ${isThai ? "กม." : "km"}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  Icons.star_rounded,
                  const Color(0xFFF59E0B),
                  rating.toStringAsFixed(1),
                  '$reviewCount ${isThai ? "รีวิว" : "reviews"}',
                ),
                Container(
                    width: 1,
                    height: 28,
                    color: AppColors.border),
                _buildStat(
                  Icons.check_circle_rounded,
                  AppColors.primary,
                  '$completedJobs',
                  isThai ? 'งานสำเร็จ' : 'completed',
                ),
                Container(
                    width: 1,
                    height: 28,
                    color: AppColors.border),
                _buildStat(
                  Icons.work_history_rounded,
                  const Color(0xFF6366F1),
                  '$experienceYears ${isThai ? "ปี" : "yr"}',
                  isThai ? 'ประสบการณ์' : 'experience',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Skills + online status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildSkillChip(isThai ? 'รักษาความปลอดภัย' : 'Security',
                    Icons.security_rounded),
                const SizedBox(width: 8),
                _buildSkillChip(
                    isThai ? 'ลาดตระเวน' : 'Patrol', Icons.directions_walk_rounded),
                const Spacer(),
                // Online indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnlineNow
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnlineNow
                              ? AppColors.primary
                              : AppColors.disabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnlineNow
                            ? (isThai ? 'ออนไลน์' : 'Online')
                            : '${minutesAgo}m',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOnlineNow
                              ? AppColors.primary
                              : AppColors.disabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed:
                    _isAssigning ? null : () => _assignGuard(guardId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isAssigningThis
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isThai ? 'ยืนยันการจอง' : 'Confirm Booking',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, Color iconColor, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.disabled,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isThai) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isThai
                  ? 'ไม่พบเจ้าหน้าที่ในขณะนี้'
                  : 'No Guards Available',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isThai
                  ? 'เจ้าหน้าที่ รปภ. ในพื้นที่ใกล้เคียง\nยังไม่ได้เปิดรับงาน กรุณาลองใหม่อีกครั้ง'
                  : 'No security guards are online nearby.\nPlease try again shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            // Retry button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _showGuardList = false);
                  _fetchGuards();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  isThai ? 'ค้นหาอีกครั้ง' : 'Search Again',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(
                isThai ? 'กลับหน้าหลัก' : 'Back to Home',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Radar painter — concentric pulse rings + sweeping line
// =============================================================================

class _RadarPainter extends CustomPainter {
  final double pulse;
  final double rotation;

  _RadarPainter({required this.pulse, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (pulse + i * 0.33) % 1.0;
      final radius = maxRadius * 0.4 + maxRadius * 0.6 * phase;
      final opacity = (1.0 - phase) * 0.25;
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }

    for (final frac in [0.35, 0.6, 0.85]) {
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, maxRadius * frac, paint);
    }

    final sweepPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dx = cos(rotation) * maxRadius * 0.85;
    final dy = sin(rotation) * maxRadius * 0.85;
    canvas.drawLine(
        center, Offset(center.dx + dx, center.dy + dy), sweepPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
}

// =============================================================================
// 3-dot bouncing indicator
// =============================================================================

class _DotsIndicator extends StatefulWidget {
  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final y = sin(t * pi) * 6;
            return Transform.translate(
              offset: Offset(0, -y),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.4 + t * 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
