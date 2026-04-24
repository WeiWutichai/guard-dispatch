import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../call_screen.dart';
import '../chat_screen.dart';
import 'active_job_screen.dart';
import 'guard_navigation_screen.dart';

class GuardJobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const GuardJobDetailScreen({super.key, required this.job});

  @override
  State<GuardJobDetailScreen> createState() => _GuardJobDetailScreenState();
}

class _GuardJobDetailScreenState extends State<GuardJobDetailScreen> {
  static const _envBaseUrl = String.fromEnvironment('API_URL');
  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  Timer? _paymentTimer;
  late Map<String, dynamic> _job;

  // WebSocket for real-time status updates
  IOWebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;

  // Progress reports
  List<Map<String, dynamic>> _progressReports = [];

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    _startPaymentPollingIfNeeded();
    _connectAssignmentWs();
    _fetchProgressReports();
  }

  Future<void> _fetchProgressReports() async {
    final assignmentId = _job['assignment_id'] as String?;
    if (assignmentId == null) return;
    try {
      await context.read<BookingProvider>().fetchProgressReports(assignmentId);
      if (!mounted) return;
      setState(() {
        _progressReports = context.read<BookingProvider>().progressReports;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _connectAssignmentWs() async {
    final requestId = _job['request_id'] as String? ?? _job['id'] as String? ?? '';
    if (requestId.isEmpty) return;

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
            if (status == 'accepted' && msg['type'] == 'status_changed') {
              _onPaymentConfirmed();
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _onPaymentConfirmed() {
    _paymentTimer?.cancel();
    _paymentTimer = null;
    final isThai = LanguageProvider.of(context).isThai;
    setState(() {
      _job['assignment_status'] = 'accepted';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isThai ? 'ลูกค้าชำระเงินแล้ว' : 'Customer has paid'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _startPaymentPollingIfNeeded() {
    final status = _job['assignment_status'] as String? ?? '';
    if (status == 'awaiting_payment') {
      _paymentTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollPaymentStatus());
    }
  }

  Future<void> _pollPaymentStatus() async {
    final requestId = _job['request_id'] as String? ?? _job['id'] as String? ?? '';
    if (requestId.isEmpty) return;
    try {
      final assignments = await context.read<BookingProvider>().getAssignments(requestId);
      if (!mounted) return;
      final assignmentId = _job['assignment_id'] as String?;
      final match = assignments.where((a) => a['id'] == assignmentId);
      if (match.isNotEmpty) {
        final newStatus = match.first['status'] as String?;
        if (newStatus == 'accepted') {
          _onPaymentConfirmed();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final isThai = LanguageProvider.of(context).isThai;

    final customerName = job['customer_name'] as String? ?? '-';
    final customerPhone = job['customer_phone'] as String?;
    final address = job['address'] as String? ?? '-';
    final description = job['description'] as String? ?? '';
    final specialInstructions = job['special_instructions'] as String?;
    final rawAssignmentStatus = job['assignment_status'] as String? ?? 'assigned';
    final startedAt = job['started_at'] as String?;
    // If status is 'arrived' but started_at is set, the job is in progress
    final assignmentStatus =
        (rawAssignmentStatus == 'arrived' && startedAt != null)
            ? 'started'
            : rawAssignmentStatus;
    final bookedHours = (job['booked_hours'] as num?)?.toInt();
    final price = job['offered_price'];
    final urgency = job['urgency'] as String? ?? 'medium';

    final detailLines = _parseDescription(description);
    final jobType = _extractJobType(description);
    final statusLabel = _statusLabel(assignmentStatus, isThai);
    final statusColor = _statusColor(assignmentStatus);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai ? 'รายละเอียดงาน' : 'Job Details',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (bookedHours != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$bookedHours ${isThai ? "ชม." : "hrs"}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Price header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: statusColor, size: 8),
                            const SizedBox(width: 8),
                            Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (price != null)
                        Text(
                          '฿${(price is num ? price : double.tryParse(price.toString()) ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Job type banner — shown prominently so guards see the
                  // job category (งานหมู่บ้าน, งานโรงงาน, ...) before accepting.
                  if (jobType != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.work_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isThai ? 'ประเภทงาน' : 'Job Type',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                jobType,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Customer info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (customerPhone != null)
                                    Text(
                                      customerPhone,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Location map
                  _buildLocationMap(job, isThai),

                  // Urgency badge
                  if (urgency != 'medium') ...[
                    const SizedBox(height: 12),
                    _buildChip(
                      Icons.flag_rounded,
                      _urgencyLabel(urgency, isThai),
                      _urgencyColor(urgency),
                    ),
                  ],

                  // Booking description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    // Extract first line as job summary if it's descriptive
                    if (detailLines.isEmpty)
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                  ],

                  // Structured detail lines
                  if (detailLines.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                isThai
                                    ? 'รายละเอียดการจอง'
                                    : 'Booking Details',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...detailLines.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(d.icon,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        d.text,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // Special instructions
                  if (specialInstructions != null &&
                      specialInstructions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Text(
                                isThai
                                    ? 'รายละเอียดเพิ่มเติมจากลูกค้า'
                                    : 'Additional Notes from Customer',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            specialInstructions,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF78350F),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Check-in timeline
                  _buildCheckinTimeline(_job, isThai),

                  // Progress reports (show for started/pending_completion/completed jobs)
                  if (assignmentStatus == 'started' ||
                      assignmentStatus == 'pending_completion' ||
                      assignmentStatus == 'completed') ...[
                    const SizedBox(height: 16),
                    _buildProgressReportsSection(isThai),
                  ],

                  // Action button area
                  if (assignmentStatus == 'pending_acceptance') ...[
                    const SizedBox(height: 24),
                    _buildAcceptDeclineButtons(context, isThai),
                  ] else if (assignmentStatus == 'awaiting_payment') ...[
                    const SizedBox(height: 24),
                    _buildAwaitingPaymentButton(isThai),
                  ] else if (assignmentStatus == 'accepted' ||
                      assignmentStatus == 'assigned' ||
                      assignmentStatus == 'en_route' ||
                      assignmentStatus == 'arrived' ||
                      assignmentStatus == 'started') ...[
                    const SizedBox(height: 24),
                    _buildStatusActionButton(context, isThai),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom call/chat bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(userName: customerName),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    label: Text(
                      isThai ? 'โทรหาลูกค้า' : 'Call Customer',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(context, isThai),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text(
                      isThai ? 'แชท' : 'Chat',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context, bool isThai) async {
    final requestId = _job['id'] as String? ?? '';
    final customerId = _job['customer_id'] as String? ?? '';
    final customerName = _job['customer_name'] as String? ?? '-';
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
            userRole: isThai ? 'ลูกค้า' : 'Client',
            actingRole: 'guard',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // =========================================================================
  // Check-in timeline
  // =========================================================================

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

  Widget _buildCheckinTimeline(Map<String, dynamic> job, bool isThai) {
    final enRouteAt = job['en_route_at'] as String?;
    final arrivedAt = job['arrived_at'] as String?;
    final startedAt = job['started_at'] as String?;

    // Only show if at least one check-in has happened
    if (enRouteAt == null && arrivedAt == null && startedAt == null) {
      return const SizedBox.shrink();
    }

    final enRoutePlace = job['en_route_place'] as String?;
    final arrivedPlace = job['arrived_place'] as String?;
    final enRouteLat = (job['en_route_lat'] as num?)?.toDouble();
    final enRouteLng = (job['en_route_lng'] as num?)?.toDouble();
    final arrivedLat = (job['arrived_lat'] as num?)?.toDouble();
    final arrivedLng = (job['arrived_lng'] as num?)?.toDouble();

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isThai ? 'ไทม์ไลน์เช็คอิน' : 'Check-in Timeline',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTimelineStep(
                icon: Icons.directions_car_rounded,
                label: isThai ? 'เริ่มเดินทาง' : 'En Route',
                time: _formatCheckinTime(enRouteAt),
                coords: enRoutePlace ?? _formatCoords(enRouteLat, enRouteLng),
                isActive: enRouteAt != null,
                isLast: false,
              ),
              _buildTimelineStep(
                icon: Icons.location_on_rounded,
                label: isThai ? 'ถึงจุดหมาย' : 'Arrived',
                time: _formatCheckinTime(arrivedAt),
                coords: arrivedPlace ?? _formatCoords(arrivedLat, arrivedLng),
                isActive: arrivedAt != null,
                isLast: false,
              ),
              _buildTimelineStep(
                icon: Icons.play_circle_rounded,
                label: isThai ? 'เริ่มงาน' : 'Started',
                time: _formatCheckinTime(startedAt),
                coords: '',
                isActive: startedAt != null,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String label,
    required String time,
    required String coords,
    required bool isActive,
    required bool isLast,
  }) {
    final color = isActive ? AppColors.primary : const Color(0xFFCBD5E1);
    final hasCoords = coords.isNotEmpty && isActive;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: hasCoords ? 36 : 24,
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Label, time, and coordinates
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (hasCoords) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.pin_drop_outlined,
                          size: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          coords,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Description parser
  // =========================================================================

  /// Extract the "ประเภทงาน: xxx" / "Job Type: xxx" line from the description
  /// blob the customer submits during booking. Returns just the value (after the colon).
  String? _extractJobType(String description) {
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('ประเภทงาน:') || lower.startsWith('job type:')) {
        final idx = trimmed.indexOf(':');
        if (idx >= 0 && idx < trimmed.length - 1) {
          final value = trimmed.substring(idx + 1).trim();
          if (value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  List<_DetailLine> _parseDescription(String description) {
    final lines = description.split('\n').where((l) => l.trim().isNotEmpty);
    final result = <_DetailLine>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      IconData icon;
      if (lower.startsWith('บริการ:') || lower.startsWith('service:')) {
        icon = Icons.shield_rounded;
      } else if (lower.startsWith('วันที่:') || lower.startsWith('date:')) {
        icon = Icons.calendar_today_rounded;
      } else if (lower.startsWith('ระยะเวลา:') ||
          lower.startsWith('duration:')) {
        icon = Icons.access_time_rounded;
      } else if (lower.startsWith('จำนวน') || lower.startsWith('guards:')) {
        icon = Icons.people_rounded;
      } else if (lower.startsWith('ประเภทงาน:') ||
          lower.startsWith('job type:')) {
        icon = Icons.work_rounded;
      } else if (lower.startsWith('บริการเพิ่มเติม:') ||
          lower.startsWith('additional:')) {
        icon = Icons.add_circle_outline_rounded;
      } else if (lower.startsWith('อุปกรณ์:') ||
          lower.startsWith('equipment:')) {
        icon = Icons.construction_rounded;
      } else if (lower.startsWith('รายละเอียดงาน:') ||
          lower.startsWith('job details:')) {
        icon = Icons.description_rounded;
      } else {
        icon = Icons.info_outline_rounded;
      }
      result.add(_DetailLine(icon: icon, text: line.trim()));
    }
    return result;
  }

  // =========================================================================
  // Progress Reports Section
  // =========================================================================

  Widget _buildProgressReportsSection(bool isThai) {
    final bookedHours = (_job['booked_hours'] as num?)?.toInt() ?? 0;
    if (bookedHours < 1) return const SizedBox.shrink();
    final totalSlots = bookedHours + 1; // 0 (เริ่มงาน) + 1..bookedHours

    // Build map of reported hours
    final reportMap = <int, Map<String, dynamic>>{};
    for (final r in _progressReports) {
      final h = r['hour_number'] as int?;
      if (h != null) reportMap[h] = r;
    }

    final missedCount = List.generate(totalSlots, (i) => i)
        .where((h) => !reportMap.containsKey(h))
        .length;

    return Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_progressReports.length}/$totalSlots',
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
          for (int h = 0; h <= bookedHours; h++) ...[
            if (h > 1) const Divider(height: 1),
            _buildHourRow(h, reportMap[h], isThai),
          ],
        ],
      ),
    );
  }

  Widget _buildHourRow(int hourNumber, Map<String, dynamic>? report, bool isThai) {
    final reported = report != null;

    Color badgeColor;
    Color badgeTextColor;
    if (reported) {
      badgeColor = AppColors.primary.withValues(alpha: 0.1);
      badgeTextColor = AppColors.primary;
    } else {
      badgeColor = Colors.red.withValues(alpha: 0.1);
      badgeTextColor = Colors.red.shade700;
    }

    String? timeDisplay;
    if (reported) {
      final createdAt = report['created_at'] as String?;
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt).toLocal();
          timeDisplay =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }

    final message = reported ? report['message'] as String? : null;
    final mediaList = reported ? (report['media'] as List?) ?? [] : [];

    return InkWell(
      onTap: reported ? () => _showReportDialog(report, isThai) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reported
                        ? (message ?? (isThai ? 'ส่งรายงานแล้ว' : 'Reported'))
                        : (isThai ? 'ไม่ได้รายงาน' : 'Missed'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: reported ? AppColors.textPrimary : Colors.red.shade700,
                    ),
                  ),
                  if (timeDisplay != null)
                    Text(
                      timeDisplay,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (reported) ...[
              if (mediaList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.image_rounded,
                      size: 16, color: AppColors.primary.withValues(alpha: 0.6)),
                ),
              Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.primary.withValues(alpha: 0.5)),
            ] else
              Icon(Icons.warning_rounded,
                  size: 18, color: Colors.red.shade600),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(Map<String, dynamic> report, bool isThai) {
    final hourNumber = report['hour_number'] as int? ?? 0;
    final message = report['message'] as String?;
    final createdAt = report['created_at'] as String?;
    final mediaList = (report['media'] as List?) ?? [];
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
                    '${isThai ? 'ชั่วโมงที่' : 'Hour'} $hourNumber',
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
                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isThai ? 'ปิด' : 'Close',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Status helpers
  // =========================================================================

  String _statusLabel(String status, bool isThai) {
    switch (status) {
      case 'pending_acceptance':
        return isThai ? 'รอตอบรับ' : 'Pending Acceptance';
      case 'accepted':
        return isThai ? 'ตอบรับแล้ว' : 'Accepted';
      case 'awaiting_payment':
        return isThai ? 'รอชำระเงิน' : 'Awaiting Payment';
      case 'assigned':
        return isThai ? 'ได้รับมอบหมาย' : 'Assigned';
      case 'en_route':
        return isThai ? 'กำลังเดินทาง' : 'En Route';
      case 'arrived':
        return isThai ? 'ถึงจุดหมาย' : 'Arrived';
      case 'started':
        return isThai ? 'กำลังดำเนินงาน' : 'In Progress';
      case 'pending_completion':
        return isThai ? 'รอลูกค้าตรวจสอบ' : 'Pending Review';
      case 'completed':
        return isThai ? 'เสร็จสิ้น' : 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_acceptance':
        return const Color(0xFFF59E0B);
      case 'accepted':
      case 'assigned':
        return AppColors.info;
      case 'awaiting_payment':
        return const Color(0xFFF59E0B);
      case 'en_route':
        return AppColors.warning;
      case 'arrived':
        return AppColors.success;
      case 'started':
        return AppColors.primary;
      case 'pending_completion':
        return Colors.orange;
      case 'completed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _urgencyLabel(String urgency, bool isThai) {
    switch (urgency) {
      case 'high':
        return isThai ? 'เร่งด่วน' : 'Urgent';
      case 'critical':
        return isThai ? 'ฉุกเฉิน' : 'Critical';
      case 'low':
        return isThai ? 'ต่ำ' : 'Low';
      default:
        return isThai ? 'ปกติ' : 'Normal';
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
      case 'critical':
        return AppColors.danger;
      case 'low':
        return AppColors.success;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Location map
  // =========================================================================

  Widget _buildLocationMap(Map<String, dynamic> job, bool isThai) {
    final lat = (job['location_lat'] as num?)?.toDouble();
    final lng = (job['location_lng'] as num?)?.toDouble();

    if (lat == null || lng == null) return const SizedBox.shrink();

    final center = LatLng(lat, lng);
    final address = job['address'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map header with expand button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isThai ? 'ตำแหน่งงาน' : 'Job Location',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openFullscreenMap(center, address, isThai),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.fullscreen_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Map
            GestureDetector(
              onTap: () => _openFullscreenMap(center, address, isThai),
              child: SizedBox(
                height: 180,
                child: AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.p-guard.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.danger,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenMap(LatLng center, String address, bool isThai) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenMapScreen(
          center: center,
          address: address,
          isThai: isThai,
        ),
      ),
    );
  }

  // =========================================================================
  // Action buttons
  // =========================================================================

  Widget _buildAcceptDeclineButtons(BuildContext context, bool isThai) {
    final assignmentId = _job['assignment_id'] as String? ?? '';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    isThai ? 'ปฏิเสธงาน' : 'Decline Job',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  content: Text(isThai
                      ? 'คุณต้องการปฏิเสธงานนี้หรือไม่?'
                      : 'Decline this job?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context
                            .read<BookingProvider>()
                            .declineAssignment(assignmentId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isThai ? 'ปฏิเสธ' : 'Decline'),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isThai ? 'ปฏิเสธ' : 'Decline',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () async {
              try {
                await context.read<BookingProvider>().acceptAssignment(assignmentId);
                if (!mounted) return;
                final updatedJob = Map<String, dynamic>.from(_job);
                updatedJob['assignment_status'] = 'awaiting_payment';
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuardJobDetailScreen(job: updatedJob),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isThai ? 'รับงาน' : 'Accept',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwaitingPaymentButton(bool isThai) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isThai
                      ? 'กรุณารอลูกค้าชำระเงิน\nเมื่อชำระเงินแล้วจะสามารถเริ่มเดินทางได้'
                      : 'Waiting for customer payment.\nYou can start the route after payment is confirmed.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_top_rounded, size: 22),
            label: Text(
              isThai ? 'รอลูกค้าชำระเงิน' : 'Awaiting Payment',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              disabledBackgroundColor:
                  const Color(0xFFF59E0B).withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Escape hatch for guards whose customer never pays — cancels this
        // assignment and frees the guard to take other work. Only available
        // while status = awaiting_payment (backend rejects after payment).
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _confirmCancelUnpaid(isThai),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(
              isThai ? 'ยกเลิกงาน (ลูกค้าไม่ชำระ)' : 'Cancel job (unpaid)',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancelUnpaid(bool isThai) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isThai ? 'ยืนยันยกเลิกงาน' : 'Cancel job?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isThai
              ? 'งานจะถูกยกเลิกและลูกค้าจะต้องเลือกเจ้าหน้าที่ใหม่ หากลูกค้าได้ชำระเงินไปแล้วจะยกเลิกไม่ได้'
              : 'This job will be cancelled and the customer will need to pick another guard. If the customer has already paid you can no longer cancel from here.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isThai ? 'ไม่' : 'No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(isThai ? 'ยกเลิกงาน' : 'Cancel job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final assignmentId = _job['assignment_id'] as String?;
    if (assignmentId == null || assignmentId.isEmpty) return;

    final nav = Navigator.of(context);
    try {
      await context
          .read<BookingProvider>()
          .cancelUnpaidAssignment(assignmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'ยกเลิกงานเรียบร้อย' : 'Job cancelled'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'ยกเลิกงานไม่สำเร็จ: $e' : 'Cancel failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStatusActionButton(BuildContext context, bool isThai) {
    final assignmentId = _job['assignment_id'] as String? ?? '';
    final rawStatus = _job['assignment_status'] as String? ?? 'assigned';
    final startedAt = _job['started_at'] as String?;
    final status = (rawStatus == 'arrived' && startedAt != null) ? 'started' : rawStatus;

    String buttonLabel;
    IconData buttonIcon;
    if (status == 'started') {
      buttonLabel = isThai ? 'ดูเวลาทำงาน' : 'View Timer';
      buttonIcon = Icons.timer_rounded;
    } else if (status == 'accepted' || status == 'assigned') {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      buttonIcon = Icons.directions_car_rounded;
    } else if (status == 'en_route') {
      buttonLabel = isThai ? 'ดูแผนที่นำทาง' : 'View Navigation';
      buttonIcon = Icons.map_rounded;
    } else if (status == 'arrived') {
      buttonLabel = isThai ? 'เริ่มงาน' : 'Start Job';
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      buttonLabel = isThai ? 'เริ่มเดินทาง' : 'Start Route';
      buttonIcon = Icons.directions_car_rounded;
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (status == 'started') {
            // Resume active job countdown
            try {
              final activeJob = await context
                  .read<BookingProvider>()
                  .fetchActiveJobData();
              if (!context.mounted) return;
              if (activeJob != null) {
                final remaining =
                    (activeJob['remaining_seconds'] as num?)?.toInt() ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveJobScreen(
                      assignmentId: assignmentId,
                      requestId: _job['request_id'] as String? ?? _job['id'] as String?,
                      customerId: _job['customer_id'] as String?,
                      customerName: _job['customer_name'] as String?,
                      address: _job['address'] as String?,
                      bookedHours:
                          (_job['booked_hours'] as num?)?.toInt() ?? 6,
                      remainingSeconds: remaining,
                      startedAt: activeJob['started_at'] as String?,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          } else if (status == 'arrived') {
            try {
              // Capture GPS at job start
              double? startLat, startLng;
              try {
                final pos = await Geolocator.getCurrentPosition(
                  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                );
                startLat = pos.latitude;
                startLng = pos.longitude;
              } catch (_) {}
              final result = await context
                  .read<BookingProvider>()
                  .startActiveJob(assignmentId, lat: startLat, lng: startLng);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveJobScreen(
                    assignmentId: assignmentId,
                    requestId: _job['request_id'] as String? ?? _job['id'] as String?,
                    customerId: _job['customer_id'] as String?,
                    customerName: _job['customer_name'] as String?,
                    address: _job['address'] as String?,
                    bookedHours:
                        (_job['booked_hours'] as num?)?.toInt() ?? 6,
                    remainingSeconds:
                        (result['remaining_seconds'] as num?)?.toInt() ??
                            (((_job['booked_hours'] as num?)?.toInt() ?? 6) *
                                3600),
                    startedAt: result['started_at'] as String?,
                  ),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          } else if (status == 'accepted' || status == 'assigned') {
            // Start Route → capture GPS + update status + navigate to map
            final customerLat = (_job['location_lat'] as num?)?.toDouble();
            final customerLng = (_job['location_lng'] as num?)?.toDouble();
            // Capture GPS at check-in
            double? gpsLat;
            double? gpsLng;
            try {
              final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              gpsLat = pos.latitude;
              gpsLng = pos.longitude;
            } catch (_) {
              // Proceed without GPS if unavailable
            }
            if (!context.mounted) return;
            await context
                .read<BookingProvider>()
                .updateAssignmentStatus(assignmentId, 'en_route', lat: gpsLat, lng: gpsLng);
            if (!context.mounted) return;
            if (customerLat != null && customerLng != null) {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardNavigationScreen(
                    assignmentId: assignmentId,
                    customerName: _job['customer_name'] as String? ?? '-',
                    customerPhone: _job['customer_phone'] as String?,
                    address: _job['address'] as String? ?? '-',
                    customerLat: customerLat,
                    customerLng: customerLng,
                  ),
                ),
              );
              if (result == 'arrived' && mounted) {
                setState(() => _job['assignment_status'] = 'arrived');
              }
            } else {
              Navigator.pop(context);
            }
          } else {
            // en_route → open navigation map
            final customerLat = (_job['location_lat'] as num?)?.toDouble();
            final customerLng = (_job['location_lng'] as num?)?.toDouble();
            if (customerLat != null && customerLng != null) {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardNavigationScreen(
                    assignmentId: assignmentId,
                    customerName: _job['customer_name'] as String? ?? '-',
                    customerPhone: _job['customer_phone'] as String?,
                    address: _job['address'] as String? ?? '-',
                    customerLat: customerLat,
                    customerLng: customerLng,
                  ),
                ),
              );
              if (result == 'arrived' && mounted) {
                setState(() => _job['assignment_status'] = 'arrived');
              }
            }
          }
        },
        icon: Icon(buttonIcon, size: 22),
        label: Text(
          buttonLabel,
          style:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _DetailLine {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});
}

// =============================================================================
// Fullscreen Map Screen
// =============================================================================

class _FullscreenMapScreen extends StatefulWidget {
  final LatLng center;
  final String address;
  final bool isThai;

  const _FullscreenMapScreen({
    required this.center,
    required this.address,
    required this.isThai,
  });

  @override
  State<_FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<_FullscreenMapScreen> {
  final MapController _mapController = MapController();

  void _zoomIn() {
    final zoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoom + 1);
  }

  void _zoomOut() {
    final zoom = _mapController.camera.zoom;
    if (zoom > 2) {
      _mapController.move(_mapController.camera.center, zoom - 1);
    }
  }

  void _recenter() {
    _mapController.move(widget.center, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.p-guard.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.center,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 56, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isThai ? 'ตำแหน่งงาน' : 'Job Location',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.address.isNotEmpty)
                          Text(
                            widget.address,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                _buildMapButton(Icons.add_rounded, _zoomIn),
                const SizedBox(height: 8),
                _buildMapButton(Icons.remove_rounded, _zoomOut),
                const SizedBox(height: 8),
                _buildMapButton(Icons.my_location_rounded, _recenter),
              ],
            ),
          ),

          // Bottom address card
          if (widget.address.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.address,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
    );
  }
}
