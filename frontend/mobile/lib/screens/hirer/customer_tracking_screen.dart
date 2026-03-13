import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import 'customer_active_job_screen.dart';

/// Customer tracking screen — shows guard's real-time location on map
/// via REST polling while guard is en_route.
class CustomerTrackingScreen extends StatefulWidget {
  final String requestId;
  final String guardId;
  final String guardName;
  final double customerLat;
  final double customerLng;

  const CustomerTrackingScreen({
    super.key,
    required this.requestId,
    required this.guardId,
    required this.guardName,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _locationTimer;
  Timer? _statusTimer;
  LatLng? _guardPosition;
  bool _waitingForLocation = true;
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    // Poll guard location every 5 seconds
    _pollLocation();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pollLocation());
    // Poll assignment status every 10 seconds
    _statusTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollStatus());
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
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
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }

  Future<void> _pollLocation() async {
    final booking = context.read<BookingProvider>();
    final data = await booking.getGuardLocation(widget.guardId);
    if (!mounted) return;

    if (data != null) {
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _guardPosition = LatLng(lat, lng);
          _waitingForLocation = false;
        });

        // Auto-fit bounds on first location
        if (!_initialFitDone) {
          _initialFitDone = true;
          final customerPos = LatLng(widget.customerLat, widget.customerLng);
          final bounds =
              LatLngBounds.fromPoints([_guardPosition!, customerPos]);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(60),
            ),
          );
        }
      }
    }
  }

  Future<void> _pollStatus() async {
    try {
      final assignments = await context
          .read<BookingProvider>()
          .getAssignments(widget.requestId);
      if (!mounted) return;

      for (final a in assignments) {
        final guardId = a['guard_id']?.toString();
        if (guardId == widget.guardId) {
          final status = a['status'] as String?;
          final startedAt = a['started_at'] as String?;

          if (status == 'arrived' && startedAt != null) {
            // Guard arrived AND started working → countdown screen
            _locationTimer?.cancel();
            _statusTimer?.cancel();
            if (!mounted) return;
            _navigateToActiveJob();
            break;
          } else if (status == 'arrived') {
            // Guard arrived but hasn't started yet
            _locationTimer?.cancel();
            _statusTimer?.cancel();
            if (!mounted) return;
            final isThai = LanguageProvider.of(context).isThai;
            final strings = CustomerTrackingStrings(isThai: isThai);
            _showArrivedDialog(strings);
            break;
          }
        }
      }
    } catch (_) {
      // Silently retry on next poll
    }
  }

  Future<void> _navigateToActiveJob() async {
    // Fetch active job info from backend for started_at + booked_hours
    final data = await context
        .read<BookingProvider>()
        .getCustomerActiveJob(widget.requestId);
    if (!mounted) return;

    final bookedHours = (data?['booked_hours'] as num?)?.toInt() ?? 6;
    final startedAt = data?['started_at'] as String?;
    final address = data?['address'] as String?;

    // Calculate remaining from startedAt locally (same reference as guard)
    int remainingSeconds;
    if (startedAt != null) {
      final startTime = DateTime.parse(startedAt);
      final elapsed = DateTime.now().toUtc().difference(startTime).inSeconds;
      final total = bookedHours * 3600;
      remainingSeconds = (total - elapsed).clamp(0, total);
    } else {
      remainingSeconds =
          (data?['remaining_seconds'] as num?)?.toInt() ?? (bookedHours * 3600);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerActiveJobScreen(
          requestId: widget.requestId,
          guardName: widget.guardName,
          address: address,
          bookedHours: bookedHours,
          remainingSeconds: remainingSeconds,
          startedAt: startedAt,
        ),
      ),
    );
  }

  void _showArrivedDialog(CustomerTrackingStrings strings) {
    // Start polling for job start after guard arrives
    _statusTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _pollForJobStart());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              strings.guardArrived,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.guardName} ${strings.hasArrived}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _statusTimer?.cancel();
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(strings.ok),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pollForJobStart() async {
    try {
      final assignments = await context
          .read<BookingProvider>()
          .getAssignments(widget.requestId);
      if (!mounted) return;

      for (final a in assignments) {
        final guardId = a['guard_id']?.toString();
        if (guardId == widget.guardId) {
          final startedAt = a['started_at'] as String?;
          if (startedAt != null) {
            _statusTimer?.cancel();
            if (!mounted) return;
            // Close arrived dialog first
            Navigator.of(context, rootNavigator: true).pop();
            _navigateToActiveJob();
            return;
          }
        }
      }
    } catch (_) {
      // Silently retry
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = CustomerTrackingStrings(isThai: isThai);
    final customerPos = LatLng(widget.customerLat, widget.customerLng);

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
                        strings.guardEnRoute,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Recenter
                if (_guardPosition != null)
                  GestureDetector(
                    onTap: () {
                      final bounds = LatLngBounds.fromPoints(
                          [_guardPosition!, customerPos]);
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(60),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: customerPos,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.secureguard.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Customer location (red pin)
                        Marker(
                          point: customerPos,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                        // Guard position (green dot)
                        if (_guardPosition != null)
                          Marker(
                            point: _guardPosition!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Zoom controls
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      _buildZoomButton(Icons.add, () {
                        final cam = _mapController.camera;
                        _mapController.move(cam.center, cam.zoom + 1);
                      }),
                      const SizedBox(height: 8),
                      _buildZoomButton(Icons.remove, () {
                        final cam = _mapController.camera;
                        _mapController.move(cam.center, cam.zoom - 1);
                      }),
                    ],
                  ),
                ),

                // Waiting indicator
                if (_waitingForLocation)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            strings.waitingForLocation,
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
            ),
          ),

          // Guard info card
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
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
                  child: const Icon(Icons.shield_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.guardName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        strings.guardEnRoute,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
