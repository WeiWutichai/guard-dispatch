import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

/// Guard navigation screen — shows embedded flutter_map with guard position
/// and customer destination. Guard taps "ถึงแล้ว" to mark arrived.
class GuardNavigationScreen extends StatefulWidget {
  final String assignmentId;
  final String customerName;
  final String? customerPhone;
  final String address;
  final double customerLat;
  final double customerLng;

  const GuardNavigationScreen({
    super.key,
    required this.assignmentId,
    required this.customerName,
    this.customerPhone,
    required this.address,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  State<GuardNavigationScreen> createState() => _GuardNavigationScreenState();
}

class _GuardNavigationScreenState extends State<GuardNavigationScreen> {
  final MapController _mapController = MapController();
  bool _isUpdating = false;
  bool _initialFitDone = false;
  bool _isFollowingGuard = true; // camera follows guard

  // OSRM route (remaining path to customer)
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeEtaMinutes;
  bool _isFetchingRoute = false;
  LatLng? _lastRouteGuardPos;

  // Traveled path (breadcrumb trail)
  final List<LatLng> _traveledPath = [];
  LatLng? _lastTraveledPos;

  static final Dio _osrmDio = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  @override
  void initState() {
    super.initState();
    // Start navigation tracking with assignment_id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().startNavigationTracking(widget.assignmentId);
    });
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

  /// Fetch driving route from OSRM. Re-fetches only if guard moved > 50m.
  Future<void> _fetchRoute(double guardLat, double guardLng) async {
    if (_isFetchingRoute) return;

    // Skip if guard hasn't moved significantly
    if (_lastRouteGuardPos != null) {
      const threshold = 0.0005; // ~50m
      final dLat = (guardLat - _lastRouteGuardPos!.latitude).abs();
      final dLng = (guardLng - _lastRouteGuardPos!.longitude).abs();
      if (dLat < threshold && dLng < threshold) return;
    }

    _isFetchingRoute = true;
    try {
      final cLng = widget.customerLng;
      final cLat = widget.customerLat;

      final response = await _osrmDio.get(
        '/route/v1/driving/$guardLng,$guardLat;$cLng,$cLat',
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
          _lastRouteGuardPos = LatLng(guardLat, guardLng);
        });
      }
    } catch (e) {
      debugPrint('OSRM route error: $e');
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _fitBounds(LatLng guardPos) {
    final customerPos = LatLng(widget.customerLat, widget.customerLng);
    final bounds = LatLngBounds.fromPoints([guardPos, customerPos]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Future<void> _onArrived() async {
    final isThai = LanguageProvider.of(context).isThai;
    setState(() => _isUpdating = true);
    try {
      // Capture GPS at arrived check-in
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
      if (!mounted) return;
      await context
          .read<BookingProvider>()
          .updateAssignmentStatus(widget.assignmentId, 'arrived', lat: gpsLat, lng: gpsLng);
      if (!mounted) return;
      // Clear navigation tracking (back to general GPS)
      context.read<TrackingProvider>().clearAssignment();
      Navigator.pop(context, 'arrived');
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardNavigationStrings(isThai: isThai);
    final tracking = context.watch<TrackingProvider>();
    final lastPos = tracking.lastPosition;

    if (lastPos != null) {
      final guardLatLng = LatLng(lastPos.latitude, lastPos.longitude);

      // Record traveled path (breadcrumb every ~20m)
      if (_lastTraveledPos == null ||
          (guardLatLng.latitude - _lastTraveledPos!.latitude).abs() > 0.0002 ||
          (guardLatLng.longitude - _lastTraveledPos!.longitude).abs() > 0.0002) {
        _traveledPath.add(guardLatLng);
        _lastTraveledPos = guardLatLng;
      }

      // First position: center on guard at navigation zoom
      if (!_initialFitDone) {
        _initialFitDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(guardLatLng, 17);
          _fetchRoute(lastPos.latitude, lastPos.longitude);
        });
      } else {
        // Follow guard: keep camera centered on guard position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_isFollowingGuard) {
            _mapController.move(guardLatLng, _mapController.camera.zoom);
          }
          _fetchRoute(lastPos.latitude, lastPos.longitude);
        });
      }
    }

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
                        strings.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Recenter / follow button
                if (lastPos != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _isFollowingGuard = true);
                      _mapController.move(
                        LatLng(lastPos.latitude, lastPos.longitude),
                        17,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isFollowingGuard
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.2),
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
                    initialZoom: 16,
                    onPositionChanged: (pos, hasGesture) {
                      // User dragged the map manually → stop following
                      if (hasGesture) {
                        _isFollowingGuard = false;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.p-guard.app',
                    ),
                    // Remaining route to customer (green)
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    // Traveled path (blue solid trail)
                    if (_traveledPath.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _traveledPath,
                            strokeWidth: 5,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Customer destination (red pin)
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
                        // Guard position (green dot with nav icon)
                        if (lastPos != null)
                          Marker(
                            point:
                                LatLng(lastPos.latitude, lastPos.longitude),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
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

                // Zoom controls + overview
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      // Overview: zoom out to see full route
                      if (lastPos != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildZoomButton(Icons.fullscreen_rounded, () {
                            setState(() => _isFollowingGuard = false);
                            _fitBounds(LatLng(lastPos.latitude, lastPos.longitude));
                          }),
                        ),
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
              ],
            ),
          ),

          // Customer info card + arrived button
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
                // Customer info
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
                            widget.customerName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.customerPhone != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phone_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Arrived button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _onArrived,
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.location_on_rounded, size: 22),
                    label: Text(
                      strings.arrived,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
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
}
