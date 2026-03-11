import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';

class ActiveJobScreen extends StatefulWidget {
  final String assignmentId;
  final String? customerName;
  final String? address;
  final int bookedHours;
  final int remainingSeconds;

  const ActiveJobScreen({
    super.key,
    required this.assignmentId,
    this.customerName,
    this.address,
    required this.bookedHours,
    required this.remainingSeconds,
  });

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  late int _remaining;
  Timer? _timer;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.remainingSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
        // Time's up — auto prompt
        _showCompleteDialog();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = widget.bookedHours * 3600;
    if (total <= 0) return 0;
    return 1.0 - (_remaining / total);
  }

  Future<void> _completeJob() async {
    final isThai = LanguageProvider.of(context).isThai;
    setState(() => _isCompleting = true);
    try {
      await context
          .read<BookingProvider>()
          .updateAssignmentStatus(widget.assignmentId, 'completed');
      if (!mounted) return;
      _timer?.cancel();
      _showSuccessAndPop(isThai);
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
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  void _showCompleteDialog() {
    final isThai = LanguageProvider.of(context).isThai;
    final hasTimeLeft = _remaining > 0;
    final hours = _remaining ~/ 3600;
    final minutes = (_remaining % 3600) ~/ 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          hasTimeLeft
              ? (isThai ? 'ยืนยันจบงาน' : 'Confirm Complete')
              : (isThai ? 'หมดเวลาแล้ว' : 'Time\'s Up'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          hasTimeLeft
              ? (isThai
                  ? 'ยังเหลือเวลาอีก $hours ชม. $minutes นาที\nต้องการจบงานหรือไม่?'
                  : 'You still have $hours hr $minutes min remaining.\nComplete the job now?')
              : (isThai
                  ? 'ระยะเวลาที่จองหมดแล้ว\nกรุณาจบงาน'
                  : 'The booked duration has ended.\nPlease complete the job.'),
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          if (hasTimeLeft)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isThai ? 'ยกเลิก' : 'Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeJob();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isThai ? 'จบงาน' : 'Complete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndPop(bool isThai) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              isThai ? 'งานเสร็จสิ้น!' : 'Job Completed!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isThai ? 'ขอบคุณสำหรับการทำงาน' : 'Thank you for your work',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isThai ? 'กลับหน้าหลัก' : 'Back to Home',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final timeStr = _formatTime(_remaining);
    final isTimeUp = _remaining <= 0;

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
                        isThai ? 'กำลังปฏิบัติงาน' : 'Active Job',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isThai ? 'นับถอยหลังเวลาทำงาน' : 'Job countdown timer',
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

            // Countdown timer ring
            SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _TimerRingPainter(
                  progress: _progress,
                  isTimeUp: isTimeUp,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: isTimeUp
                              ? AppColors.danger
                              : AppColors.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isThai ? 'เวลาที่เหลือ' : 'Remaining',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Job details
            if (widget.customerName != null || widget.address != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (widget.customerName != null)
                      _buildDetailRow(
                        Icons.person_rounded,
                        isThai ? 'ลูกค้า' : 'Customer',
                        widget.customerName!,
                      ),
                    if (widget.customerName != null && widget.address != null)
                      const SizedBox(height: 12),
                    if (widget.address != null)
                      _buildDetailRow(
                        Icons.location_on_rounded,
                        isThai ? 'สถานที่' : 'Location',
                        widget.address!,
                      ),
                  ],
                ),
              ),

            const Spacer(flex: 3),

            // Complete job button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isCompleting ? null : _showCompleteDialog,
                  icon: _isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    isThai ? 'เสร็จสิ้นงาน' : 'Complete Job',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isTimeUp ? AppColors.danger : AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool isTimeUp;

  _TimerRingPainter({required this.progress, required this.isTimeUp});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = isTimeUp ? AppColors.danger : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress || old.isTimeUp != isTimeUp;
}
