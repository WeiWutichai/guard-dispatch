import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/auth_service.dart';
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
  static const _envBaseUrl = String.fromEnvironment('API_URL');
  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  late int _remaining;
  Timer? _timer;
  Timer? _syncTimer;
  Timer? _statusTimer;
  bool _isCompleting = false;
  bool _isPendingCompletion = false;

  // WebSocket for real-time status updates (customer review detection)
  IOWebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _remaining = widget.remainingSeconds;

    // Local 1-second countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0 && !_isPendingCompletion) {
        setState(() => _remaining--);
      } else if (_remaining <= 0 && !_isPendingCompletion) {
        _timer?.cancel();
        _showCompleteDialog();
      }
    });

    // Sync with server every 30 seconds to correct drift
    _syncTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _resyncTimer());

    // Immediate sync to get accurate server time
    _resyncTimer();
  }

  Future<void> _connectAssignmentWs(String requestId) async {
    if (_wsChannel != null) return; // Already connected

    final token = await AuthService.getAccessToken();
    if (token == null) return;

    final wsUrl = _defaultBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ws/assignments');

    try {
      _wsChannel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: const Duration(seconds: 30),
      );
      await _wsChannel!.ready;
      _wsChannel!.sink.add(requestId);

      _wsSub = _wsChannel!.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final status = msg['status'] as String?;
            if (status != null && msg['type'] == 'status_changed') {
              _handleWsStatusChange(status);
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _handleWsStatusChange(String status) {
    if (status == 'completed') {
      _timer?.cancel();
      _syncTimer?.cancel();
      _statusTimer?.cancel();
      final isThai = LanguageProvider.of(context).isThai;
      _showSuccessAndPop(isThai);
    } else if (status == 'arrived' && _isPendingCompletion) {
      setState(() => _isPendingCompletion = false);
      _statusTimer?.cancel();
      _statusTimer = null;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining > 0 && !_isPendingCompletion) {
          setState(() => _remaining--);
        } else if (_remaining <= 0 && !_isPendingCompletion) {
          _timer?.cancel();
          _showCompleteDialog();
        }
      });
      _resyncTimer();
      final isThai = LanguageProvider.of(context).isThai;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai
              ? 'ลูกค้าขอให้ทำงานต่อ'
              : 'Customer requested to continue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.amber.shade700,
        ),
      );
    }
  }

  Future<void> _resyncTimer() async {
    final data = await context.read<BookingProvider>().fetchActiveJobData();
    if (!mounted || data == null) return;

    // Connect WebSocket once we have request_id
    final reqId = data['request_id'] as String?;
    if (reqId != null && _requestId == null) {
      _requestId = reqId;
      _connectAssignmentWs(reqId);
    }

    // Check if status changed (customer approved or held)
    final status = data['assignment_status'] as String?;
    if (status == 'completed') {
      _timer?.cancel();
      _syncTimer?.cancel();
      _statusTimer?.cancel();
      final isThai = LanguageProvider.of(context).isThai;
      _showSuccessAndPop(isThai);
      return;
    }
    if (status == 'arrived' && _isPendingCompletion) {
      // Customer held — resume countdown
      setState(() => _isPendingCompletion = false);
      _statusTimer?.cancel();
      _statusTimer = null;

      // Restart countdown timer if it was cancelled
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining > 0 && !_isPendingCompletion) {
          setState(() => _remaining--);
        } else if (_remaining <= 0 && !_isPendingCompletion) {
          _timer?.cancel();
          _showCompleteDialog();
        }
      });

      final isThai = LanguageProvider.of(context).isThai;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai
              ? 'ลูกค้าขอให้ทำงานต่อ'
              : 'Customer requested to continue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.amber.shade700,
        ),
      );
    }
    if (status == 'pending_completion' && !_isPendingCompletion) {
      setState(() => _isPendingCompletion = true);
      _startStatusPolling();
    }

    // Prefer started_at-based calculation for consistency with customer screen
    final serverStartedAt = data['started_at'] as String?;
    if (serverStartedAt != null) {
      final startTime = DateTime.parse(serverStartedAt);
      final elapsed = DateTime.now().toUtc().difference(startTime).inSeconds;
      final total = widget.bookedHours * 3600;
      setState(() => _remaining = (total - elapsed).clamp(0, total));
      return;
    }

    // Fallback to server-calculated remaining_seconds
    final serverRemaining = (data['remaining_seconds'] as num?)?.toInt();
    if (serverRemaining != null) {
      setState(() => _remaining = serverRemaining);
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    final data = await context.read<BookingProvider>().fetchActiveJobData();
    if (!mounted || data == null) return;

    final status = data['assignment_status'] as String?;
    if (status == 'completed') {
      _timer?.cancel();
      _syncTimer?.cancel();
      _statusTimer?.cancel();
      final isThai = LanguageProvider.of(context).isThai;
      _showSuccessAndPop(isThai);
    } else if (status == 'arrived' && _isPendingCompletion) {
      // Customer held — resume working
      setState(() => _isPendingCompletion = false);
      _statusTimer?.cancel();
      _statusTimer = null;

      // Restart countdown timer if it was cancelled (e.g. time ran out)
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining > 0 && !_isPendingCompletion) {
          setState(() => _remaining--);
        } else if (_remaining <= 0 && !_isPendingCompletion) {
          _timer?.cancel();
          _showCompleteDialog();
        }
      });

      // Immediate resync to get accurate remaining time
      _resyncTimer();

      final isThai = LanguageProvider.of(context).isThai;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai
              ? 'ลูกค้าขอให้ทำงานต่อ'
              : 'Customer requested to continue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.amber.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncTimer?.cancel();
    _statusTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
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
          .updateAssignmentStatus(widget.assignmentId, 'pending_completion');
      if (!mounted) return;
      setState(() {
        _isPendingCompletion = true;
        _isCompleting = false;
      });
      _startStatusPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'เกิดข้อผิดพลาด: $e' : 'Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
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
              isThai ? 'ลูกค้าอนุมัติปิดงานแล้ว' : 'Customer approved completion',
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
                  Navigator.pop(ctx);
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

    // Determine status badge
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;
    if (_isPendingCompletion) {
      badgeColor = Colors.amber.shade700;
      badgeIcon = Icons.hourglass_top_rounded;
      badgeText = isThai ? 'รอลูกค้าตรวจสอบ' : 'Waiting for customer review';
    } else if (isTimeUp) {
      badgeColor = AppColors.danger;
      badgeIcon = Icons.timer_off_rounded;
      badgeText = isThai ? 'หมดเวลาแล้ว' : 'Time\'s Up';
    } else {
      badgeColor = AppColors.primary;
      badgeIcon = Icons.security_rounded;
      badgeText = isThai ? 'กำลังปฏิบัติหน้าที่' : 'On Duty';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header with back button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                        isThai
                            ? 'นับถอยหลังเวลาทำงาน'
                            : 'Job countdown timer',
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
                isPending: _isPendingCompletion,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPendingCompletion) ...[
                      Icon(Icons.hourglass_top_rounded,
                          size: 40, color: Colors.amber.shade700),
                      const SizedBox(height: 8),
                      Text(
                        isThai ? 'รอตรวจสอบ' : 'Pending',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ] else ...[
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
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Job details card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                if (widget.customerName != null) ...[
                  _buildDetailRow(
                    Icons.person_rounded,
                    isThai ? 'ลูกค้า' : 'Customer',
                    widget.customerName!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.address != null) ...[
                  _buildDetailRow(
                    Icons.location_on_rounded,
                    isThai ? 'สถานที่' : 'Location',
                    widget.address!,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow(
                  Icons.access_time_rounded,
                  isThai ? 'ระยะเวลาจอง' : 'Booked Duration',
                  '${widget.bookedHours} ${isThai ? 'ชั่วโมง' : 'hours'}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Status badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(badgeIcon, size: 20, color: badgeColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          // Complete job button (disabled when pending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_isCompleting || _isPendingCompletion)
                    ? null
                    : _showCompleteDialog,
                icon: _isCompleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        _isPendingCompletion
                            ? Icons.hourglass_top_rounded
                            : Icons.check_circle_rounded,
                        size: 22,
                      ),
                label: Text(
                  _isPendingCompletion
                      ? (isThai ? 'รอลูกค้าอนุมัติ' : 'Waiting for approval')
                      : (isThai ? 'เสร็จสิ้นงาน' : 'Complete Job'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPendingCompletion
                      ? Colors.amber.shade700
                      : (isTimeUp ? AppColors.danger : AppColors.primary),
                  disabledBackgroundColor: _isPendingCompletion
                      ? Colors.amber.shade200
                      : AppColors.primary.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _isPendingCompletion
                      ? Colors.amber.shade800
                      : Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Back to home button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isThai ? 'กลับหน้าหลัก' : 'Back to Home',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
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
  final bool isPending;

  _TimerRingPainter({
    required this.progress,
    required this.isTimeUp,
    this.isPending = false,
  });

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
    final Color arcColor;
    if (isPending) {
      arcColor = const Color(0xFFF59E0B); // amber
    } else if (isTimeUp) {
      arcColor = AppColors.danger;
    } else {
      arcColor = AppColors.primary;
    }

    final progressPaint = Paint()
      ..color = arcColor
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
      old.progress != progress ||
      old.isTimeUp != isTimeUp ||
      old.isPending != isPending;
}
