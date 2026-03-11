import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import 'payment_screen.dart';

class WaitingForGuardScreen extends StatefulWidget {
  final String requestId;
  final String assignmentId;
  final String guardName;
  final double guardRating;
  final double guardDistance;
  final String? guardAvatarUrl;
  final double totalAmount;
  final double subtotal;
  final double baseFee;
  final double tip;
  final int bookedHours;
  final int guardCount;

  const WaitingForGuardScreen({
    super.key,
    required this.requestId,
    required this.assignmentId,
    required this.guardName,
    required this.guardRating,
    required this.guardDistance,
    this.guardAvatarUrl,
    required this.totalAmount,
    required this.subtotal,
    required this.baseFee,
    required this.tip,
    required this.bookedHours,
    required this.guardCount,
  });

  @override
  State<WaitingForGuardScreen> createState() => _WaitingForGuardScreenState();
}

class _WaitingForGuardScreenState extends State<WaitingForGuardScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseCtrl;
  bool _declined = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final assignments =
          await context.read<BookingProvider>().getAssignments(widget.requestId);
      if (!mounted) return;

      // Find our assignment
      final assignment = assignments.firstWhere(
        (a) => a['id'] == widget.assignmentId,
        orElse: () => <String, dynamic>{},
      );

      final status = assignment['status'] as String?;
      if (status == 'accepted') {
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              requestId: widget.requestId,
              totalAmount: widget.totalAmount,
              subtotal: widget.subtotal,
              baseFee: widget.baseFee,
              tip: widget.tip,
              bookedHours: widget.bookedHours,
              guardCount: widget.guardCount,
              guardName: widget.guardName,
            ),
          ),
        );
      } else if (status == 'declined') {
        _pollTimer?.cancel();
        setState(() => _declined = true);
      }
    } catch (_) {
      // Silently retry on next poll
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    if (_declined) {
      return _buildDeclinedView(isThai);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SecureGuard',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isThai
                            ? 'รอเจ้าหน้าที่ตอบรับ'
                            : 'Waiting for guard',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Pulsing animation
            SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _PulsePainter(progress: _pulseCtrl.value),
                    child: child,
                  );
                },
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: widget.guardAvatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.guardAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.person_rounded,
                            size: 36, color: AppColors.primary),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              widget.guardName,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Rating + distance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  widget.guardRating.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.near_me_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${widget.guardDistance.toStringAsFixed(1)} ${isThai ? "กม." : "km"}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Waiting text
            Text(
              isThai ? 'รอเจ้าหน้าที่ตอบรับ...' : 'Waiting for guard to accept...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isThai
                  ? 'ระบบกำลังแจ้งเตือนเจ้าหน้าที่'
                  : 'Notifying the guard now',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const Spacer(flex: 3),

            // Cancel button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    _pollTimer?.cancel();
                    final nav = Navigator.of(context);
                    try {
                      await context
                          .read<BookingProvider>()
                          .cancelRequest(widget.requestId);
                    } catch (_) {}
                    if (mounted) {
                      nav.popUntil((route) => route.isFirst);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isThai ? 'ยกเลิก' : 'Cancel',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclinedView(bool isThai) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 56, color: AppColors.danger),
                ),
                const SizedBox(height: 24),
                Text(
                  isThai ? 'เจ้าหน้าที่ปฏิเสธ' : 'Guard Declined',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isThai
                      ? 'กรุณาเลือกเจ้าหน้าที่คนอื่น'
                      : 'Please select another guard',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isThai ? 'กลับไปเลือกเจ้าหน้าที่' : 'Back to Guard List',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  _PulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = 30 + (maxRadius - 30) * phase;
      final opacity = (1.0 - phase) * 0.2;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppColors.primary.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => true;
}
