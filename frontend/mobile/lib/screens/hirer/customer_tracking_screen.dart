import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
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
  String? _enRouteAt;
  double? _enRouteLat;
  double? _enRouteLng;
  String? _enRoutePlace;

  // Route line
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeEtaMinutes;
  bool _isFetchingRoute = false;
  LatLng? _lastRouteGuardPos; // avoid re-fetching if guard hasn't moved much

  static final Dio _osrmDio = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

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

        // Fetch route after position update
        _fetchRoute();

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

  /// Fetch driving route from OSRM between guard and customer.
  /// Only re-fetches if guard moved > 50m since last fetch.
  Future<void> _fetchRoute() async {
    if (_guardPosition == null || _isFetchingRoute) return;

    // Skip if guard hasn't moved significantly (> 50m)
    if (_lastRouteGuardPos != null) {
      const threshold = 0.0005; // ~50m in degrees
      final dLat = (_guardPosition!.latitude - _lastRouteGuardPos!.latitude).abs();
      final dLng = (_guardPosition!.longitude - _lastRouteGuardPos!.longitude).abs();
      if (dLat < threshold && dLng < threshold) return;
    }

    _isFetchingRoute = true;
    try {
      final gLng = _guardPosition!.longitude;
      final gLat = _guardPosition!.latitude;
      final cLng = widget.customerLng;
      final cLat = widget.customerLat;

      final response = await _osrmDio.get(
        '/route/v1/driving/$gLng,$gLat;$cLng,$cLat',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
        },
      );

      if (!mounted) return;

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;
        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();

        setState(() {
          _routePoints = coords
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          _routeDistanceKm = distance / 1000;
          _routeEtaMinutes = (duration / 60).ceil();
          _lastRouteGuardPos = _guardPosition;
        });
      }
    } catch (e) {
      debugPrint('OSRM route error: $e');
    } finally {
      _isFetchingRoute = false;
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

          // Capture en_route check-in data for display
          final enRouteAt = a['en_route_at'] as String?;
          if (enRouteAt != null && _enRouteAt == null) {
            setState(() {
              _enRouteAt = enRouteAt;
              _enRouteLat = (a['en_route_lat'] as num?)?.toDouble();
              _enRouteLng = (a['en_route_lng'] as num?)?.toDouble();
              _enRoutePlace = a['en_route_place'] as String?;
            });
          }

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

  String _formatCheckinTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
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
                      userAgentPackageName: 'com.p-guard.app',
                    ),
                    // Route polyline (draw before markers so it's behind)
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                        ],
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
                        // Guard position (green dot with pulse)
                        if (_guardPosition != null)
                          Marker(
                            point: _guardPosition!,
                            width: 32,
                            height: 32,
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
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ETA + distance badge
                if (_routeEtaMinutes != null && _routeDistanceKm != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_car_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai
                                      ? 'ถึงในอีก ~$_routeEtaMinutes นาที'
                                      : 'Arrives in ~$_routeEtaMinutes min',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isThai
                                      ? 'ระยะทาง ${_routeDistanceKm!.toStringAsFixed(1)} กม.'
                                      : '${_routeDistanceKm!.toStringAsFixed(1)} km away',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_routeDistanceKm!.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strings.guardEnRoute,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // En route time + location badge
                    if (_enRouteAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCheckinTime(_enRouteAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (_enRoutePlace != null || (_enRouteLat != null && _enRouteLng != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pin_drop_outlined,
                                        size: 10,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.7)),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        _enRoutePlace ?? '${_enRouteLat!.toStringAsFixed(5)}, ${_enRouteLng!.toStringAsFixed(5)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
