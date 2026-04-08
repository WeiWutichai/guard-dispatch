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
import '../../l10n/app_strings.dart';
import 'job_completion_summary_screen.dart';

/// Customer view of guard's active job countdown — read-only, no pause/stop.
class CustomerActiveJobScreen extends StatefulWidget {
  final String requestId;
  final String guardName;
  final String? address;
  final int bookedHours;
  final int remainingSeconds;
  final String? startedAt;

  const CustomerActiveJobScreen({
    super.key,
    required this.requestId,
    required this.guardName,
    this.address,
    required this.bookedHours,
    required this.remainingSeconds,
    this.startedAt,
  });

  @override
  State<CustomerActiveJobScreen> createState() =>
      _CustomerActiveJobScreenState();
}

class _CustomerActiveJobScreenState extends State<CustomerActiveJobScreen> {
  static const _envBaseUrl = String.fromEnvironment('API_URL');
  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  // DEBUG: must match guard's active_job_screen.dart settings
  static const _debugFastTimer = true;
  static const _debugSpeedMultiplier = 120; // must match guard's _debugTickAmount

  late int _remaining;
  String? _serverStartedAt; // single source of truth from server
  String _guardName = '-';
  Timer? _timer;
  Timer? _statusTimer;
  bool _isPendingCompletion = false;
  bool _isReviewDialogShown = false;
  bool _isSubmitting = false;

  // Check-in timestamps and locations (populated from server sync)
  String? _enRouteAt;
  String? _arrivedAt;
  String? _startedAtDisplay;
  double? _enRouteLat;
  double? _enRouteLng;
  double? _arrivedLat;
  double? _arrivedLng;
  String? _enRoutePlace;
  String? _arrivedPlace;
  String? _startedPlace;
  String? _completionPlace;
  String? _completionRequestedAt;

  // Progress reports from guard
  List<Map<String, dynamic>> _progressReports = [];
  String? _assignmentId;
  int _lastReportPoll = 0; // track poll count to throttle report fetches

  // WebSocket for real-time status updates
  IOWebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;

  /// Calculate remaining seconds from a started_at timestamp string.
  /// Uses same speed multiplier as guard so both screens show identical time.
  int _calcRemainingFromStartedAt(String startedAtStr) {
    final startedAt = DateTime.parse(startedAtStr);
    final realElapsed = DateTime.now().toUtc().difference(startedAt).inSeconds;
    final elapsed = _debugFastTimer ? realElapsed * _debugSpeedMultiplier : realElapsed;
    final total = widget.bookedHours * 3600;
    return (total - elapsed).clamp(0, total);
  }

  @override
  void initState() {
    super.initState();
    _guardName = widget.guardName;
    _serverStartedAt = widget.startedAt;

    // Calculate initial remaining from started_at (same reference as guard)
    if (_serverStartedAt != null) {
      _remaining = _calcRemainingFromStartedAt(_serverStartedAt!);
    } else {
      _remaining = widget.remainingSeconds;
    }

    // Recalculate from started_at every second — no independent countdown.
    // Both guard and customer derive time from the same started_at timestamp.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPendingCompletion && _serverStartedAt != null) {
        final r = _calcRemainingFromStartedAt(_serverStartedAt!);
        if (r != _remaining) {
          setState(() => _remaining = r);
        }
      }
    });

    // Poll assignment status every 3 seconds (also syncs started_at)
    _statusTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus());

    // Immediate sync to get accurate server time
    _resyncTimer();

    // Connect WebSocket for real-time assignment status updates
    _connectAssignmentWs();
  }

  Future<void> _connectAssignmentWs() async {
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

      // Send request_id as first message (per CLAUDE.md — no IDs in URL)
      _wsChannel!.sink.add(widget.requestId);

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
        onError: (_) {
          // WebSocket error — polling fallback continues
        },
        onDone: () {
          // Connection closed — polling fallback continues
        },
      );
    } catch (_) {
      // Failed to connect — polling fallback handles updates
    }
  }

  void _handleWsStatusChange(String status) {
    if (status == 'completed') {
      _timer?.cancel();
      _statusTimer?.cancel();
      setState(() => _isPendingCompletion = false);
      _showCompletedDialog();
    } else if (status == 'pending_completion' && !_isReviewDialogShown) {
      _timer?.cancel();
      _timer = null;
      setState(() => _isPendingCompletion = true);
      _fetchAndShowReview();
    } else if (status == 'arrived' && _isPendingCompletion) {
      // Guard resumed (customer rejected completion)
      setState(() {
        _isPendingCompletion = false;
        _isReviewDialogShown = false;
      });
      _resyncTimer();
      // Restart display timer — recalculates from started_at each tick
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPendingCompletion && _serverStartedAt != null) {
          final r = _calcRemainingFromStartedAt(_serverStartedAt!);
          if (r != _remaining) {
            setState(() => _remaining = r);
          }
        }
      });
    }
  }

  Future<void> _fetchAndShowReview() async {
    try {
      final assignments = await context
          .read<BookingProvider>()
          .getAssignments(widget.requestId);
      if (!mounted) return;
      for (final a in assignments) {
        if (a['status'] == 'pending_completion') {
          _showReviewDialog(a);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _resyncTimer() async {
    final data = await context
        .read<BookingProvider>()
        .getCustomerActiveJob(widget.requestId);
    if (!mounted || data == null) return;

    // Update guard name from server (field is 'customer_name' in ActiveJobResponse)
    final serverName = data['customer_name'] as String?;
    if (serverName != null && serverName != '-' && serverName.isNotEmpty) {
      _guardName = serverName;
    }

    // Update check-in timestamps and locations from server
    final enRouteAt = data['en_route_at'] as String?;
    final arrivedAt = data['arrived_at'] as String?;
    final startedAtVal = data['started_at'] as String?;
    setState(() {
      _enRouteAt = enRouteAt ?? _enRouteAt;
      _arrivedAt = arrivedAt ?? _arrivedAt;
      _startedAtDisplay = startedAtVal ?? _startedAtDisplay;
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

    // Extract assignment_id for progress reports
    final assignId = data['assignment_id'] as String?;
    if (assignId != null && assignId != _assignmentId) {
      _assignmentId = assignId;
    }

    // Fetch progress reports if we have an assignment ID
    if (_assignmentId != null) {
      _fetchProgressReports();
    }

    // Update started_at — the single source of truth for timer calculation.
    // Both guard and customer derive remaining time from this same timestamp.
    final serverStartedAt = data['started_at'] as String?;
    if (serverStartedAt != null) {
      _serverStartedAt = serverStartedAt;
      setState(() => _remaining = _calcRemainingFromStartedAt(serverStartedAt));
    } else if (_serverStartedAt != null) {
      // Already have started_at from previous sync — recalculate (don't fallback to real-time)
      setState(() => _remaining = _calcRemainingFromStartedAt(_serverStartedAt!));
    } else {
      // No started_at yet (job not started) — use server remaining as initial estimate
      final serverRemaining = (data['remaining_seconds'] as num?)?.toInt();
      if (serverRemaining != null) {
        setState(() => _remaining = serverRemaining);
      }
    }
  }

  Future<void> _fetchProgressReports() async {
    if (_assignmentId == null) return;
    try {
      await context
          .read<BookingProvider>()
          .fetchProgressReports(_assignmentId!);
      if (!mounted) return;
      final reports = context.read<BookingProvider>().progressReports;
      setState(() => _progressReports = reports);
    } catch (_) {
      // Silently fail — reports are supplementary
    }
  }

  Future<void> _pollStatus() async {
    // Re-fetch progress reports every ~3rd poll (~9s) instead of every 3s
    _lastReportPoll++;
    if (_lastReportPoll % 3 == 0) {
      _fetchProgressReports();
    }

    try {
      final assignments = await context
          .read<BookingProvider>()
          .getAssignments(widget.requestId);
      if (!mounted) return;

      for (final a in assignments) {
        final status = a['status'] as String?;
        // Update started_at from assignment data if available
        final aStartedAt = a['started_at'] as String?;
        if (aStartedAt != null) {
          _serverStartedAt = aStartedAt;
        }

        if (status == 'completed') {
          _timer?.cancel();
          _statusTimer?.cancel();
          setState(() => _isPendingCompletion = false);
          _showCompletedDialog();
          return;
        }
        if (status == 'pending_completion' && !_isReviewDialogShown) {
          _timer?.cancel();
          _timer = null;
          setState(() => _isPendingCompletion = true);
          _showReviewDialog(a);
          return;
        }
        if (status == 'arrived' && _isPendingCompletion) {
          // Guard resumed (customer rejected completion)
          setState(() {
            _isPendingCompletion = false;
            _isReviewDialogShown = false;
          });
          _resyncTimer();
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!_isPendingCompletion && _serverStartedAt != null) {
              final r = _calcRemainingFromStartedAt(_serverStartedAt!);
              if (r != _remaining) {
                setState(() => _remaining = r);
              }
            }
          });
          return;
        }
      }
    } catch (_) {
      // Silently retry
    }
  }

  void _showCompletedDialog() {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = CustomerActiveJobStrings(isThai: isThai);

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
              strings.jobCompleted,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.jobCompletedMsg,
              textAlign: TextAlign.center,
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
                  strings.backToHome,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(Map<String, dynamic> assignment) {
    _isReviewDialogShown = true;
    final isThai = LanguageProvider.of(context).isThai;
    final strings = CustomerActiveJobStrings(isThai: isThai);
    final assignmentId = assignment['id'] as String? ?? '';

    // Parse times — in debug fast mode, apply speed multiplier to worked duration
    final startedAtStr = assignment['started_at'] as String?;
    final completionAtStr = assignment['completion_requested_at'] as String?;

    String startTimeDisplay = '-';
    String endTimeDisplay = '-';
    String workedDisplay = '-';

    if (startedAtStr != null) {
      final startedAt = DateTime.parse(startedAtStr).toLocal();
      startTimeDisplay =
          '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}';
    }
    if (completionAtStr != null) {
      if (_debugFastTimer && startedAtStr != null) {
        // In debug mode, calculate simulated end time
        final startUtc = DateTime.parse(startedAtStr);
        final endUtc = DateTime.parse(completionAtStr);
        final realDiffSec = endUtc.difference(startUtc).inSeconds;
        final simulatedEnd = startUtc.add(Duration(seconds: realDiffSec * _debugSpeedMultiplier));
        final localEnd = simulatedEnd.toLocal();
        endTimeDisplay =
            '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';
      } else {
        final completionAt = DateTime.parse(completionAtStr).toLocal();
        endTimeDisplay =
            '${completionAt.hour.toString().padLeft(2, '0')}:${completionAt.minute.toString().padLeft(2, '0')}';
      }
    }
    if (startedAtStr != null && completionAtStr != null) {
      final realDiff = DateTime.parse(completionAtStr)
          .difference(DateTime.parse(startedAtStr));
      // In debug mode, multiply real elapsed by speed to get simulated worked time
      final workedSeconds = _debugFastTimer
          ? realDiff.inSeconds * _debugSpeedMultiplier
          : realDiff.inSeconds;
      final h = workedSeconds ~/ 3600;
      final m = (workedSeconds % 3600) ~/ 60;
      workedDisplay = h > 0
          ? '$h ${strings.hours} $m ${strings.minutes}'
          : '$m ${strings.minutes}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rate_review_rounded,
                    size: 40, color: Colors.amber.shade700),
              ),
              const SizedBox(height: 20),
              Text(
                strings.reviewTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.reviewSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              // Review details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildReviewRow(
                        Icons.shield_rounded, strings.guard, _guardName),
                    const SizedBox(height: 10),
                    _buildReviewRow(Icons.play_circle_rounded,
                        strings.startTime, startTimeDisplay),
                    const SizedBox(height: 10),
                    _buildReviewRow(Icons.stop_circle_rounded,
                        strings.endTime, endTimeDisplay),
                    const SizedBox(height: 10),
                    _buildReviewRow(Icons.timelapse_rounded,
                        strings.workedDuration, workedDisplay),
                    const SizedBox(height: 10),
                    _buildReviewRow(Icons.schedule_rounded,
                        strings.bookedDuration, '${widget.bookedHours} ${strings.hours}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Approve button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _handleApprove(ctx, assignmentId, setDialogState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          strings.approveCompletion,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // Close button — dismiss dialog, customer can approve later
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isThai ? 'ปิด' : 'Close',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Dialog dismissed — _isReviewDialogShown stays true.
    // Customer re-opens via the on-screen button.
  }

  Future<void> _handleApprove(
    BuildContext dialogCtx,
    String assignmentId,
    void Function(void Function()) setDialogState,
  ) async {
    setDialogState(() => _isSubmitting = true);
    setState(() => _isSubmitting = true);

    try {
      await context
          .read<BookingProvider>()
          .reviewCompletion(assignmentId, true);
      if (!mounted) return;

      Navigator.pop(dialogCtx);

      _timer?.cancel();
      
      _statusTimer?.cancel();
      _wsSub?.cancel();
      _wsChannel?.sink.close();

      // Show cost summary first (with optional tip), then ReviewRatingScreen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JobCompletionSummaryScreen(
            assignmentId: assignmentId,
            guardName: _guardName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setDialogState(() => _isSubmitting = false);
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    
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

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = CustomerActiveJobStrings(isThai: isThai);
    final timeStr = _formatTime(_remaining);
    final isTimeUp = _remaining <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header
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
                        strings.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        strings.subtitle,
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
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isTimeUp
                                    ? AppColors.danger
                                    : AppColors.textPrimary,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.remaining,
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
                        _buildDetailRow(
                          Icons.shield_rounded,
                          strings.guard,
                          _guardName,
                        ),
                        const SizedBox(height: 12),
                        if (widget.address != null) ...[
                          _buildDetailRow(
                            Icons.location_on_rounded,
                            strings.location,
                            widget.address!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildDetailRow(
                          Icons.access_time_rounded,
                          strings.bookedHours,
                          '${widget.bookedHours} ${strings.hours}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Check-in timeline
                  _buildCheckinTimeline(isThai),

                  // Progress reports from guard
                  _buildProgressReportsSection(isThai),

                  const SizedBox(height: 16),

                  // Status badge
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isPendingCompletion
                          ? Colors.amber.withValues(alpha: 0.1)
                          : isTimeUp
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPendingCompletion
                            ? Colors.amber.withValues(alpha: 0.4)
                            : isTimeUp
                                ? AppColors.danger.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPendingCompletion
                              ? Icons.rate_review_rounded
                              : isTimeUp
                                  ? Icons.timer_off_rounded
                                  : Icons.security_rounded,
                          size: 20,
                          color: _isPendingCompletion
                              ? Colors.amber.shade700
                              : isTimeUp
                                  ? AppColors.danger
                                  : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isPendingCompletion
                                ? strings.pendingReview
                                : isTimeUp
                                    ? strings.timeUpMsg
                                    : strings.guardWorking,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isPendingCompletion
                                  ? Colors.amber.shade700
                                  : isTimeUp
                                      ? AppColors.danger
                                      : AppColors.primary,
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
          if (_isPendingCompletion)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _isReviewDialogShown = false;
                    _fetchAndShowReview();
                  },
                  icon: const Icon(Icons.rate_review_rounded, size: 22),
                  label: Text(
                    strings.approveCompletion,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  strings.backToHome,
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

  /// Format end time — in debug mode, calculate simulated end time from started_at + (realDiff * multiplier)
  String _formatSimulatedEndTime(String? completionIso) {
    if (completionIso == null) return '--:--';
    try {
      if (_debugFastTimer && _startedAtDisplay != null) {
        final start = DateTime.parse(_startedAtDisplay!);
        final end = DateTime.parse(completionIso);
        final realDiffSec = end.difference(start).inSeconds;
        final simulatedEnd = start.add(Duration(seconds: realDiffSec * _debugSpeedMultiplier));
        final local = simulatedEnd.toLocal();
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      final dt = DateTime.parse(completionIso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _formatCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  Widget _buildProgressReportsSection(bool isThai) {
    final prStrings = ProgressReportStrings(isThai: isThai);
    final totalSlots = widget.bookedHours + 1; // 0 (เริ่มงาน) + 1..bookedHours

    // Calculate current period
    final total = widget.bookedHours * 3600;
    final elapsed = total - _remaining;
    final period = elapsed ~/ 3600;

    // Build set of reported hour numbers
    final reportedHours = <int>{};
    final reportMap = <int, Map<String, dynamic>>{};
    for (final r in _progressReports) {
      final h = r['hour_number'] as int?;
      if (h != null) {
        reportedHours.add(h);
        reportMap[h] = r;
      }
    }

    // Determine which hours to show
    List<int> visibleHours;
    if (_isPendingCompletion || _remaining <= 0) {
      // Job done — show all slots 0..bookedHours
      visibleHours = List.generate(totalSlots, (i) => i);
    } else {
      // During job — show only reported + missed (past deadline)
      final missedSet = <int>{};
      for (int h = 0; h < period && h <= widget.bookedHours; h++) {
        if (!reportedHours.contains(h)) missedSet.add(h);
      }
      visibleHours = <int>{...reportedHours, ...missedSet}.toList()..sort();
    }

    if (visibleHours.isEmpty) return const SizedBox.shrink();

    // Missed = visible but not reported
    final missedHours = visibleHours.where((h) => !reportedHours.contains(h)).toSet();
    final missedCount = missedHours.length;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_rounded,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    prStrings.progressReports,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${reportedHours.length}/$totalSlots',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (missedCount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 14, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Text(
                        isThai
                            ? 'ไม่ได้รายงาน $missedCount รอบ'
                            : '$missedCount missed report${missedCount > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              for (int i = 0; i < visibleHours.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildCustomerHourRow(
                  visibleHours[i],
                  isThai,
                  reported: reportedHours.contains(visibleHours[i]),
                  missed: missedHours.contains(visibleHours[i]),
                  report: reportMap[visibleHours[i]],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerHourRow(
    int hourNumber,
    bool isThai, {
    required bool reported,
    required bool missed,
    Map<String, dynamic>? report,
  }) {
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

    return InkWell(
      onTap: reported && report != null
          ? () => _showCustomerReportDetail(report, isThai)
          : null,
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
                hourNumber == 0
                    ? (isThai ? 'เริ่มงาน' : 'Start')
                    : '${isThai ? 'ชม.' : 'Hr'} $hourNumber',
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
                        : (isThai ? 'รอรายงาน' : 'Pending'),
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
              Icon(Icons.schedule_rounded,
                  size: 18, color: Colors.orange.shade400),
          ],
        ),
      ),
    );
  }

  void _showCustomerReportDetail(Map<String, dynamic> report, bool isThai) {
    final prStrings = ProgressReportStrings(isThai: isThai);
    final hourNumber = report['hour_number'] as int? ?? 0;
    final message = report['message'] as String?;
    final createdAt = report['created_at'] as String?;
    final mediaList = (report['media'] as List<dynamic>?) ?? [];
    final photoUrl = report['photo_url'] as String?;

    String timeDisplay = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        timeDisplay =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    hourNumber == 0
                        ? (isThai ? 'เริ่มงาน' : 'Start')
                        : '${prStrings.hourLabel} $hourNumber',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (timeDisplay.isNotEmpty)
                    Text(
                      timeDisplay,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(message, style: GoogleFonts.inter(fontSize: 14)),
              ],
              if (mediaList.isNotEmpty || photoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    mediaList.isNotEmpty
                        ? (mediaList.first['url'] as String? ?? '')
                        : (photoUrl ?? ''),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isThai ? 'ปิด' : 'Close',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckinTimeline(bool isThai) {
    if (_enRouteAt == null && _arrivedAt == null && _startedAtDisplay == null) {
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
            _formatCheckinTime(_startedAtDisplay),
            _startedPlace ?? '',
            _startedAtDisplay != null,
          ),
          if (_completionRequestedAt != null) ...[
            const SizedBox(height: 6),
            _buildTimelineRow(
              Icons.stop_circle_rounded,
              isThai ? 'สิ้นสุดงาน' : 'Job Ended',
              _formatSimulatedEndTime(_completionRequestedAt),
              _completionPlace != null
                  ? '$_completionPlace\n${_formatWorkedDuration(isThai)}'
                  : _formatWorkedDuration(isThai),
              true,
            ),
          ],
        ],
      ),
    );
  }

  String _formatWorkedDuration(bool isThai) {
    if (_startedAtDisplay == null || _completionRequestedAt == null) return '';
    try {
      final start = DateTime.parse(_startedAtDisplay!);
      final end = DateTime.parse(_completionRequestedAt!);
      final realDiff = end.difference(start);
      // In debug mode, multiply real elapsed by speed to get simulated worked time
      final workedSeconds = _debugFastTimer
          ? realDiff.inSeconds * _debugSpeedMultiplier
          : realDiff.inSeconds;
      final h = workedSeconds ~/ 3600;
      final m = (workedSeconds % 3600) ~/ 60;
      if (h > 0) {
        return isThai
            ? 'ระยะเวลาทำงาน $h ชม. $m นาที'
            : 'Worked $h hr $m min';
      }
      return isThai
          ? 'ระยะเวลาทำงาน $m นาที'
          : 'Worked $m min';
    } catch (_) {
      return '';
    }
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
    final progressPaint = Paint()
      ..color = isPending
          ? const Color(0xFFF59E0B) // amber
          : isTimeUp
              ? AppColors.danger
              : AppColors.primary
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
