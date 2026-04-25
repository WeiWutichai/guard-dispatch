import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../l10n/app_strings.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../chat_screen.dart';

class ActiveJobScreen extends StatefulWidget {
  final String assignmentId;
  final String? requestId;
  final String? customerId;
  final String? customerName;
  final String? address;
  final int bookedHours;
  final int remainingSeconds;
  final String? startedAt;

  const ActiveJobScreen({
    super.key,
    required this.assignmentId,
    this.requestId,
    this.customerId,
    this.customerName,
    this.address,
    required this.bookedHours,
    required this.remainingSeconds,
    this.startedAt,
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

  // DEBUG: set true to speed up countdown (1 sec = 6 min for testing)
  static const _debugFastTimer = true;
  static const _debugTickAmount = 120; // 1 real second = 120s sim → 1 hour per ~30s

  late int _remaining;
  Timer? _timer;
  Timer? _syncTimer;
  Timer? _statusTimer;
  bool _isCompleting = false;
  bool _isPendingCompletion = false;

  // Progress report tracking
  final Set<int> _reportedHours = {}; // actually submitted
  final Map<int, Map<String, dynamic>> _reportData = {}; // hour → report data
  final Set<int> _dismissedHours = {}; // skipped auto-popup (don't re-trigger)
  final Set<int> _missedHours = {}; // past hours with no report (deadline passed)
  int _lastCheckedHour = 0;
  bool _isReportDialogOpen = false;
  int? _openDialogHour; // which hour's dialog is currently open
  bool _reportsLoaded = false; // gate _checkHourBoundary until hour-1 handled

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
  String? _customerId;

  /// Calculate remaining seconds from a started_at timestamp string.
  /// Uses same speed multiplier as debug fast timer so both screens match.
  int _calcRemainingFromStartedAt(String startedAtStr) {
    final startedAt = DateTime.parse(startedAtStr);
    final realElapsed = DateTime.now().toUtc().difference(startedAt).inSeconds;
    final elapsed = _debugFastTimer ? realElapsed * _debugTickAmount : realElapsed;
    final total = widget.bookedHours * 3600;
    return (total - elapsed).clamp(0, total);
  }

  /// Recalculate _remaining from started_at. Called every tick.
  void _recalcFromStartedAt() {
    final ref = _startedAt ?? widget.startedAt;
    if (ref != null) {
      final r = _calcRemainingFromStartedAt(ref);
      if (r != _remaining) {
        setState(() => _remaining = r);
        _checkHourBoundary();
        if (_remaining <= 0) {
          _timer?.cancel();
          _handleTimeUp();
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
    _customerId = widget.customerId;
    // Use startedAt for accurate initial value; fall back to passed-in value
    if (widget.startedAt != null) {
      _remaining = _calcRemainingFromStartedAt(widget.startedAt!);
    } else {
      _remaining = widget.remainingSeconds;
    }

    // Recalculate from started_at every second — same formula as customer.
    // Both screens derive time from the same started_at + speed multiplier.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPendingCompletion) {
        _recalcFromStartedAt();
      }
    });

    // Sync with server every 30 seconds
    _syncTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _resyncTimer());

    // Immediate sync to get accurate server time
    _resyncTimer();

    // Load existing reports, then trigger hour-0 report (เริ่มปฏิบัติงาน)
    _loadExistingReports().then((_) {
      if (!mounted) return;
      // Auto-show initial report (hour 0 = เริ่มปฏิบัติงาน) immediately
      if (!_reportedHours.contains(0) &&
          !_dismissedHours.contains(0) &&
          !_isReportDialogOpen) {
        _showProgressReportDialog(0, autoPopup: true);
      }
      _reportsLoaded = true;
      _checkHourBoundary();
    });
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
        if (!_isPendingCompletion) _recalcFromStartedAt();
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
    final custId = data['customer_id'] as String?;
    if (custId != null && _customerId == null) {
      _customerId = custId;
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

      // Restart timer — recalculates from started_at each tick
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPendingCompletion) _recalcFromStartedAt();
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

    // Sync remaining from started_at (uses speed multiplier in debug mode)
    final serverStartedAt = data['started_at'] as String?;
    if (serverStartedAt != null) {
      setState(() => _remaining = _calcRemainingFromStartedAt(serverStartedAt));
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

      // Restart timer — recalculates from started_at each tick
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPendingCompletion) _recalcFromStartedAt();
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

  /// When time is up: show final hour report popup first, then complete dialog.
  void _handleTimeUp() {
    final lastHour = widget.bookedHours;
    if (!_reportedHours.contains(lastHour) &&
        !_missedHours.contains(lastHour) &&
        !_isReportDialogOpen) {
      // Show final hour report — complete dialog after it closes
      _showFinalHourReport(lastHour);
    } else {
      _showCompleteDialog();
    }
  }

  void _showFinalHourReport(int hourNumber) {
    _isReportDialogOpen = true;
    _openDialogHour = hourNumber;
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
      if (!mounted) return;
      _isReportDialogOpen = false;
      _openDialogHour = null;
      _loadExistingReports();
      // Now show the complete dialog
      _showCompleteDialog();
    });
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

  Future<void> _openChat(BuildContext context, bool isThai) async {
    final requestId = _requestId ?? '';
    final customerId = _customerId ?? '';
    final customerName = widget.customerName ?? '-';
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    var myUserId = authProvider.userId;
    if (myUserId == null) {
      await authProvider.fetchProfile();
      myUserId = authProvider.userId;
    }

    if (myUserId == null || requestId.isEmpty || customerId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'ไม่สามารถเปิดแชทได้' : 'Cannot open chat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final conversationId = await chatProvider
          .getOrCreateConversation(requestId, myUserId, customerId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            requestId: requestId,
            userName: customerName,
            userId: customerId,
            userRole: isThai ? 'ลูกค้า' : 'Client',
            actingRole: 'guard',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    }
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
    if (!_reportsLoaded) return;

    final total = widget.bookedHours * 3600;
    final elapsed = total - _remaining;
    // period = which 1-hour period we're in (0 = first hour, 1 = second, ...)
    final period = elapsed ~/ 3600;

    if (period > _lastCheckedHour) {
      // Mark unreported hours whose deadline just passed as missed.
      // period 0→1: hour 0 (เริ่มปฏิบัติงาน) deadline passed at minute 60
      // period 1→2: hour 1 (ชั่วโมงที่ 1) deadline passed at minute 120
      for (int p = _lastCheckedHour; p < period; p++) {
        // Don't mark the final hour — _handleTimeUp gives it a chance
        if (p < widget.bookedHours && !_reportedHours.contains(p)) {
          _missedHours.add(p);
        }
      }

      _lastCheckedHour = period;

      // If a dialog is open for a now-missed hour, close it first.
      if (_isReportDialogOpen &&
          _openDialogHour != null &&
          _missedHours.contains(_openDialogHour)) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      _openNextHourPopupIfNeeded();
    }
  }

  /// Open popup for the current period's hour if eligible.
  /// period 1 → popup hour 1, period 2 → popup hour 2, etc.
  void _openNextHourPopupIfNeeded() {
    if (!mounted) return;
    final total = widget.bookedHours * 3600;
    final elapsed = total - _remaining;
    final period = elapsed ~/ 3600;
    // At period N, popup for hour N (0-indexed report numbers)
    if (period < widget.bookedHours &&
        !_reportedHours.contains(period) &&
        !_dismissedHours.contains(period) &&
        !_missedHours.contains(period) &&
        !_isReportDialogOpen) {
      _showProgressReportDialog(period, autoPopup: true);
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
          if (h != null) {
            _reportedHours.add(h);
            _reportData[h] = r;
          }
        }
        // Set _lastCheckedHour so we don't re-trigger for past hours
        final total = widget.bookedHours * 3600;
        final elapsed = total - _remaining;
        _lastCheckedHour = elapsed ~/ 3600;
      });
    } catch (_) {}
  }

  /// Build a section showing each booked hour with report status.
  /// Unreported past hours get a button to submit retroactively.
  Widget _buildProgressReportsSection(bool isThai) {
    // Total report slots: 0 (เริ่มปฏิบัติงาน) + 1..bookedHours
    final totalSlots = widget.bookedHours + 1; // e.g. 4 hrs → 5 reports (0-4)
    int maxSlot;
    if (_isPendingCompletion || _remaining <= 0) {
      maxSlot = widget.bookedHours; // show all including final
    } else {
      final total = widget.bookedHours * 3600;
      final elapsed = total - _remaining;
      final period = elapsed ~/ 3600;
      maxSlot = period.clamp(0, widget.bookedHours);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded,
                  size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                isThai ? 'รายงานความคืบหน้า' : 'Progress Reports',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${_reportedHours.length}/$totalSlots',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int h = 0; h <= maxSlot; h++) ...[
            if (h > 0) const Divider(height: 1),
            _buildHourReportRow(h, isThai),
          ],
        ],
      ),
    );
  }

  /// Label for each report slot
  String _reportLabel(int hourNumber, bool isThai) {
    if (hourNumber == 0) return isThai ? 'เริ่มงาน' : 'Start';
    if (hourNumber == widget.bookedHours) {
      return isThai ? 'ชม. $hourNumber' : 'Hr $hourNumber';
    }
    return isThai ? 'ชม. $hourNumber' : 'Hr $hourNumber';
  }

  Widget _buildHourReportRow(int hourNumber, bool isThai) {
    final reported = _reportedHours.contains(hourNumber);
    final missed = _missedHours.contains(hourNumber);

    Color badgeColor;
    Color badgeTextColor;
    if (reported) {
      badgeColor = AppColors.primary.withValues(alpha: 0.1);
      badgeTextColor = AppColors.primary;
    } else if (missed) {
      badgeColor = Colors.red.withValues(alpha: 0.1);
      badgeTextColor = Colors.red.shade700;
    } else {
      badgeColor = Colors.orange.withValues(alpha: 0.1);
      badgeTextColor = Colors.orange.shade700;
    }

    final label = _reportLabel(hourNumber, isThai);

    return InkWell(
      onTap: reported ? () => _showReportDetail(hourNumber, isThai) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reported
                    ? (isThai ? 'ส่งรายงานแล้ว' : 'Reported')
                    : missed
                        ? (isThai ? 'ไม่ได้รายงาน' : 'Missed')
                        : (isThai ? 'ยังไม่ได้ส่งรายงาน' : 'Not reported'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: reported
                      ? AppColors.primary
                      : missed
                          ? Colors.red.shade700
                          : AppColors.textSecondary,
                ),
              ),
            ),
            if (reported) ...[
              Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
            ] else if (missed)
              Icon(Icons.warning_rounded,
                  size: 20, color: Colors.red.shade600)
            else
              SizedBox(
                height: 30,
                child: TextButton(
                  onPressed: () => _showProgressReportDialog(hourNumber),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isThai ? 'ส่งรายงาน' : 'Submit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReportDetail(int hourNumber, bool isThai) {
    final report = _reportData[hourNumber];
    if (report == null) return;

    final message = report['message'] as String?;
    final createdAt = report['created_at'] as String?;
    final mediaList = report['media'] as List? ?? [];
    final photoUrl = report['photo_url'] as String?;

    // Format timestamp
    String? formattedTime;
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year;
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        formattedTime = '$day/$month/$year $hour:$min';
      } catch (_) {}
    }

    // Build media URLs list: prefer media array, fallback to photo_url
    final List<Map<String, dynamic>> mediaItems = [];
    for (final m in mediaList) {
      if (m is Map<String, dynamic>) mediaItems.add(m);
    }
    if (mediaItems.isEmpty && photoUrl != null) {
      mediaItems.add({'url': photoUrl, 'mime_type': 'image/jpeg'});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title + timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_turned_in_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isThai
                            ? 'รายงานชั่วโมงที่ $hourNumber'
                            : 'Hour $hourNumber Report',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              if (formattedTime != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      '${isThai ? 'รายงานเมื่อ' : 'Reported at'} $formattedTime',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
                ],
              ),
            ),
            const Divider(height: 24),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media thumbnails
                    if (mediaItems.isNotEmpty) ...[
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: mediaItems.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, idx) {
                            final item = mediaItems[idx];
                            final url = item['url'] as String? ?? '';
                            final mime =
                                item['mime_type'] as String? ?? 'image/jpeg';
                            final isVideo = mime.startsWith('video/');

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  if (isVideo)
                                    Container(
                                      width: 180,
                                      height: 180,
                                      color: Colors.black87,
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    )
                                  else
                                    Image.network(
                                      url,
                                      width: 180,
                                      height: 180,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 180,
                                        height: 180,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Message
                    if (message != null && message.isNotEmpty) ...[
                      Text(
                        isThai ? 'ข้อความ' : 'Message',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          message,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                    ],
                    if (message == null || message.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            isThai
                                ? 'ไม่มีข้อความประกอบ'
                                : 'No message attached',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgressReportDialog(int hourNumber, {bool autoPopup = false}) {
    // Don't allow opening dialog for missed hours
    if (_missedHours.contains(hourNumber)) return;

    _isReportDialogOpen = true;
    _openDialogHour = hourNumber;
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
      if (!mounted) return;
      _isReportDialogOpen = false;
      _openDialogHour = null;
      // For auto-popup: mark as dismissed so it doesn't re-trigger
      if (autoPopup) _dismissedHours.add(hourNumber);
      // Reload reports from server to update reported status
      _loadExistingReports();
      // If this popup was closed by hour boundary, open next hour's popup
      _openNextHourPopupIfNeeded();
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
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isTimeUp
                                      ? AppColors.danger
                                      : AppColors.textPrimary,
                                  letterSpacing: 1,
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

                  const SizedBox(height: 12),

                  // Progress reports section (submit for any past hour)
                  _buildProgressReportsSection(isThai),

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

          // Chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _openChat(context, isThai),
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: Text(
                  isThai ? 'แชทกับลูกค้า' : 'Chat with Customer',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.primary),
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
                Expanded(
                  child: Text(
                    coords,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
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
        Expanded(
          child: Column(
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
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
  static const _maxFiles = 5;
  final _messageController = TextEditingController();
  final List<File> _files = [];
  bool _isSubmitting = false;
  bool _isCompressing = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool _isVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ext == 'mp4' || ext == 'mov';
  }

  Future<File> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Calculate target size — max 800px on longest side
      const maxDim = 800;
      int targetW = image.width;
      int targetH = image.height;
      if (targetW > maxDim || targetH > maxDim) {
        if (targetW >= targetH) {
          targetH = (targetH * maxDim / targetW).round();
          targetW = maxDim;
        } else {
          targetW = (targetW * maxDim / targetH).round();
          targetH = maxDim;
        }
      }

      // Resize
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final byteData =
          await resizedFrame.image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      resizedFrame.image.dispose();

      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final outPath =
            '${file.parent.path}/resized_${DateTime.now().millisecondsSinceEpoch}.png';
        final outFile = File(outPath);
        await outFile.writeAsBytes(pngBytes);
        debugPrint(
            'Compressed: ${bytes.length} → ${pngBytes.length} bytes (${targetW}x$targetH)');
        return outFile;
      }
    } catch (e) {
      debugPrint('Image compress error: $e');
    }
    return file;
  }

  Future<void> _pickImages() async {
    if (_files.length >= _maxFiles) return;
    final picker = ImagePicker();
    List<XFile> picked;
    try {
      picked = await picker.pickMultiImage();
    } catch (e) {
      debugPrint('pickMultiImage error: $e');
      return;
    }
    if (picked.isEmpty || !mounted) return;
    final remaining = _maxFiles - _files.length;
    final toAdd = picked.take(remaining).toList();
    setState(() => _isCompressing = true);
    try {
      final result = <File>[];
      for (final xFile in toAdd) {
        final original = File(xFile.path);
        result.add(await _compressImage(original));
      }
      if (!mounted) return;
      setState(() => _files.addAll(result));
    } catch (e) {
      debugPrint('Image pick/compress error: $e');
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  Future<void> _pickFromCamera() async {
    if (_files.length >= _maxFiles) return;
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      debugPrint('pickImage camera error: $e');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _isCompressing = true);
    final compressed = await _compressImage(File(picked.path));
    if (!mounted) return;
    setState(() {
      _files.add(compressed);
      _isCompressing = false;
    });
  }

  Future<void> _pickVideo() async {
    if (_files.length >= _maxFiles) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked != null && mounted) {
        setState(() => _files.add(File(picked.path)));
      }
    } catch (_) {}
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  Future<void> _submit() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isThai
                ? 'กรุณาแนบรูปภาพหรือวิดีโออย่างน้อย 1 รายการ'
                : 'Please attach at least 1 photo or video',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    debugPrint('[ProgressReport] submit hour=${widget.hourNumber} files=${_files.length}');
    setState(() => _isSubmitting = true);
    try {
      await context.read<BookingProvider>().submitProgressReport(
            widget.assignmentId,
            hourNumber: widget.hourNumber,
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
            files: _files,
          );
      debugPrint('[ProgressReport] submit success');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('[ProgressReport] submit error: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Show error as dialog (visible over bottom sheet)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            widget.isThai ? 'เกิดข้อผิดพลาด' : 'Error',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            _formatErrorMessage(e),
            style: GoogleFonts.inter(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(widget.isThai ? 'ตกลง' : 'OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Show the actual server `error.message` (e.g. "File too large: ... 50MB")
  /// instead of Dio's generic toString. Mirrors the helper in CallScreen +
  /// profile_settings_screen so guards see actionable text.
  String _formatErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (data['message'] is String) return data['message'] as String;
      }
      final s = e.response?.statusCode;
      if (s != null) {
        return widget.isThai ? 'ส่งไม่สำเร็จ (HTTP $s)' : 'Submit failed (HTTP $s)';
      }
      return widget.isThai ? 'เครือข่ายขัดข้อง' : 'Network error';
    }
    return e.toString();
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

            // Files preview (thumbnails grid)
            if (_files.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isVid = _isVideo(file);
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isVid
                              ? Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.black87,
                                  child: const Center(
                                    child: Icon(Icons.videocam_rounded,
                                        color: Colors.white, size: 36),
                                  ),
                                )
                              : Image.file(file,
                                  width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeFile(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${_files.length}/$_maxFiles ${s.filesSelected}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Compressing indicator
            if (_isCompressing) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.compressing,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Pick buttons (camera / gallery / video)
            if (_files.length < _maxFiles && !_isCompressing) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoButton(
                      Icons.camera_alt_rounded,
                      s.takePhoto,
                      _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPhotoButton(
                      Icons.photo_library_rounded,
                      s.chooseGallery,
                      _pickImages,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPhotoButton(
                      Icons.videocam_rounded,
                      s.recordVideo,
                      _pickVideo,
                    ),
                  ),
                ],
              ),
            ] else if (_files.length >= _maxFiles) ...[
              Center(
                child: Text(
                  s.maxFilesReached,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                onPressed: (_isSubmitting || _isCompressing) ? null : _submit,
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
