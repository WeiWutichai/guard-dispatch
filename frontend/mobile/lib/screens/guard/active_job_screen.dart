import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../l10n/app_strings.dart';
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

  // Progress report tracking
  final Set<int> _reportedHours = {};
  int _lastCheckedHour = 0;
  bool _isReportDialogOpen = false;

  // Check-in timestamps and locations (populated from server sync)
  String? _enRouteAt;
  String? _arrivedAt;
  String? _startedAt;
  double? _enRouteLat;
  double? _enRouteLng;
  double? _arrivedLat;
  double? _arrivedLng;
  String? _enRoutePlace;
  String? _arrivedPlace;
  String? _startedPlace;
  String? _completionPlace;
  String? _completionRequestedAt;

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
        _checkHourBoundary();
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

    // Load existing reports to populate _reportedHours
    _loadExistingReports();
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

    // Update check-in timestamps and locations from server
    final enRouteAt = data['en_route_at'] as String?;
    final arrivedAt = data['arrived_at'] as String?;
    final startedAtVal = data['started_at'] as String?;
    setState(() {
      _enRouteAt = enRouteAt ?? _enRouteAt;
      _arrivedAt = arrivedAt ?? _arrivedAt;
      _startedAt = startedAtVal ?? _startedAt;
      _enRouteLat = (data['en_route_lat'] as num?)?.toDouble() ?? _enRouteLat;
      _enRouteLng = (data['en_route_lng'] as num?)?.toDouble() ?? _enRouteLng;
      _arrivedLat = (data['arrived_lat'] as num?)?.toDouble() ?? _arrivedLat;
      _arrivedLng = (data['arrived_lng'] as num?)?.toDouble() ?? _arrivedLng;
      _enRoutePlace = (data['en_route_place'] as String?) ?? _enRoutePlace;
      _arrivedPlace = (data['arrived_place'] as String?) ?? _arrivedPlace;
      _startedPlace = (data['started_place'] as String?) ?? _startedPlace;
      _completionPlace = (data['completion_place'] as String?) ?? _completionPlace;
      _completionRequestedAt = (data['completion_requested_at'] as String?) ?? _completionRequestedAt;
    });

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
      // Capture GPS at completion
      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
      await context
          .read<BookingProvider>()
          .updateAssignmentStatus(widget.assignmentId, 'pending_completion', lat: lat, lng: lng);
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

  // =========================================================================
  // Progress Report — Hour Boundary Detection
  // =========================================================================

  void _checkHourBoundary() {
    final total = widget.bookedHours * 3600;
    final elapsed = total - _remaining;
    final currentHour = elapsed ~/ 3600; // 0→1→2→3...

    if (currentHour > _lastCheckedHour && currentHour <= widget.bookedHours) {
      _lastCheckedHour = currentHour;
      if (!_reportedHours.contains(currentHour) && !_isReportDialogOpen) {
        _showProgressReportDialog(currentHour);
      }
    }
  }

  Future<void> _loadExistingReports() async {
    try {
      final reports = await context
          .read<BookingProvider>()
          .fetchProgressReports(widget.assignmentId)
          .then((_) => context.read<BookingProvider>().progressReports);
      if (!mounted) return;
      setState(() {
        for (final r in reports) {
          final h = r['hour_number'] as int?;
          if (h != null) _reportedHours.add(h);
        }
        // Set _lastCheckedHour so we don't re-trigger for past hours
        final total = widget.bookedHours * 3600;
        final elapsed = total - _remaining;
        _lastCheckedHour = elapsed ~/ 3600;
      });
    } catch (_) {}
  }

  void _showProgressReportDialog(int hourNumber) {
    _isReportDialogOpen = true;
    final isThai = LanguageProvider.of(context).isThai;
    final strings = ProgressReportStrings(isThai: isThai);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProgressReportSheet(
        hourNumber: hourNumber,
        assignmentId: widget.assignmentId,
        strings: strings,
        isThai: isThai,
      ),
    ).then((_) {
      _isReportDialogOpen = false;
      // Mark hour as handled (whether submitted or skipped)
      setState(() => _reportedHours.add(hourNumber));
    });
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

          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Countdown timer ring
                  SizedBox(
                    width: 220,
                    height: 220,
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

                  const SizedBox(height: 24),

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

                  const SizedBox(height: 12),

                  // Check-in timeline
                  _buildCheckinTimeline(isThai),

                  const SizedBox(height: 16),

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
                ],
              ),
            ),
          ),

          // Bottom buttons (fixed)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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

  String _formatCheckinTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _formatCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  Widget _buildCheckinTimeline(bool isThai) {
    if (_enRouteAt == null && _arrivedAt == null && _startedAt == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                isThai ? 'เช็คอิน' : 'Check-in',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTimelineRow(
            Icons.directions_car_rounded,
            isThai ? 'เริ่มเดินทาง' : 'En Route',
            _formatCheckinTime(_enRouteAt),
            _enRoutePlace ?? _formatCoords(_enRouteLat, _enRouteLng),
            _enRouteAt != null,
          ),
          const SizedBox(height: 6),
          _buildTimelineRow(
            Icons.location_on_rounded,
            isThai ? 'ถึงจุดหมาย' : 'Arrived',
            _formatCheckinTime(_arrivedAt),
            _arrivedPlace ?? _formatCoords(_arrivedLat, _arrivedLng),
            _arrivedAt != null,
          ),
          const SizedBox(height: 6),
          _buildTimelineRow(
            Icons.play_circle_rounded,
            isThai ? 'เริ่มงาน' : 'Started',
            _formatCheckinTime(_startedAt),
            _startedPlace ?? '',
            _startedAt != null,
          ),
          if (_completionRequestedAt != null) ...[
            const SizedBox(height: 6),
            _buildTimelineRow(
              Icons.check_circle_rounded,
              isThai ? 'สิ้นสุดงาน' : 'Job Ended',
              _formatCheckinTime(_completionRequestedAt),
              _completionPlace ?? '',
              true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
      IconData icon, String label, String time, String coords, bool isActive) {
    final color = isActive ? AppColors.primary : const Color(0xFFCBD5E1);
    final hasCoords = coords.isNotEmpty && isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (hasCoords)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Row(
              children: [
                Icon(Icons.pin_drop_outlined,
                    size: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  coords,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
      ],
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

// =============================================================================
// Progress Report Bottom Sheet
// =============================================================================

class _ProgressReportSheet extends StatefulWidget {
  final int hourNumber;
  final String assignmentId;
  final ProgressReportStrings strings;
  final bool isThai;

  const _ProgressReportSheet({
    required this.hourNumber,
    required this.assignmentId,
    required this.strings,
    required this.isThai,
  });

  @override
  State<_ProgressReportSheet> createState() => _ProgressReportSheetState();
}

class _ProgressReportSheetState extends State<_ProgressReportSheet> {
  final _messageController = TextEditingController();
  File? _photo;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<BookingProvider>().submitProgressReport(
            widget.assignmentId,
            hourNumber: widget.hourNumber,
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
            photo: _photo,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.strings.submitSuccess),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.strings.submitError}: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${s.hourLabel} ${widget.hourNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Photo section
            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _photo!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _photo = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    widget.isThai ? 'ลบรูป' : 'Remove Photo',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoButton(
                      Icons.camera_alt_rounded,
                      s.takePhoto,
                      () => _pickPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPhotoButton(
                      Icons.photo_library_rounded,
                      s.chooseGallery,
                      () => _pickPhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Message input
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: s.messagePlaceholder,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSubmitting ? s.submitting : s.submit,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Skip button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: Text(
                  s.skip,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
