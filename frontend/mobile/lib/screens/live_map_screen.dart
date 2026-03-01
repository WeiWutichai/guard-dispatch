import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';

/// Guard status derived from last update time.
enum GuardStatus { active, idle, alert }

/// Precomputed stats for a guard list (single-pass).
class _GuardStats {
  final int total;
  final int active;
  final int idle;
  final int alert;

  const _GuardStats({
    required this.total,
    required this.active,
    required this.idle,
    required this.alert,
  });

  factory _GuardStats.from(List<DisplayGuard> guards) {
    int active = 0, idle = 0, alert = 0;
    for (final g in guards) {
      switch (g.status) {
        case GuardStatus.active:
          active++;
        case GuardStatus.idle:
          idle++;
        case GuardStatus.alert:
          alert++;
      }
    }
    return _GuardStats(
      total: guards.length,
      active: active,
      idle: idle,
      alert: alert,
    );
  }
}

/// Display model for a guard on the live map.
class DisplayGuard {
  final String id;
  final String name;
  final GuardStatus status;
  final String location;
  final LatLng position;
  final DateTime lastUpdate;

  const DisplayGuard({
    required this.id,
    required this.name,
    required this.status,
    required this.location,
    required this.position,
    required this.lastUpdate,
  });
}

/// Allowed roles that can view the live tracking map.
const _allowedMapRoles = {'admin', 'customer'};

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  String _filterStatus = 'all';
  String? _selectedGuardId;

  // Demo data — will be replaced by WebSocket / REST from tracking service
  final List<DisplayGuard> _guards = [
    DisplayGuard(
      id: 'G001',
      name: 'Somchai Prasert',
      status: GuardStatus.active,
      location: 'Central Plaza - Main Entrance',
      position: const LatLng(13.7563, 100.5018),
      lastUpdate: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    DisplayGuard(
      id: 'G002',
      name: 'Niran Thongchai',
      status: GuardStatus.active,
      location: 'Siam Paragon - Parking B2',
      position: const LatLng(13.7466, 100.5347),
      lastUpdate: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
    DisplayGuard(
      id: 'G003',
      name: 'Kittisak Srisawat',
      status: GuardStatus.idle,
      location: 'Terminal 21 - Floor 3',
      position: const LatLng(13.7378, 100.5604),
      lastUpdate: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    DisplayGuard(
      id: 'G004',
      name: 'Wichai Kaewsai',
      status: GuardStatus.alert,
      location: 'ICONSIAM - Waterfront',
      position: const LatLng(13.7268, 100.5100),
      lastUpdate: DateTime.now().subtract(const Duration(seconds: 30)),
    ),
    DisplayGuard(
      id: 'G005',
      name: 'Thanakorn Mee',
      status: GuardStatus.active,
      location: 'Mega Bangna - East Wing',
      position: const LatLng(13.6614, 100.6840),
      lastUpdate: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
  ];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<DisplayGuard> _computeFiltered() {
    if (_filterStatus == 'all') return _guards;
    final target = GuardStatus.values.firstWhere(
      (s) => s.name == _filterStatus,
    );
    return _guards.where((g) => g.status == target).toList();
  }

  static Color statusColor(GuardStatus status) {
    switch (status) {
      case GuardStatus.active:
        return AppColors.primary;
      case GuardStatus.idle:
        return AppColors.warning;
      case GuardStatus.alert:
        return AppColors.danger;
    }
  }

  static Color _statusBgColor(GuardStatus status) {
    switch (status) {
      case GuardStatus.active:
        return const Color(0xFFECFDF5);
      case GuardStatus.idle:
        return const Color(0xFFFFFBEB);
      case GuardStatus.alert:
        return const Color(0xFFFEF2F2);
    }
  }

  static String _formatTimeAgo(DateTime dt, LiveMapStrings strings) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return strings.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${strings.minAgo}';
    return '${diff.inHours} ${strings.hourAgo}';
  }

  void _onGuardTap(DisplayGuard guard) {
    final isDeselecting = _selectedGuardId == guard.id;
    setState(() {
      _selectedGuardId = isDeselecting ? null : guard.id;
    });
    if (!isDeselecting) {
      _mapController.move(guard.position, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Authorization: only admin/customer can view all guard locations
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated ||
        (auth.role != null && !_allowedMapRoles.contains(auth.role))) {
      return _buildUnauthorized(context);
    }

    final isThai = LanguageProvider.of(context).isThai;
    final strings = LiveMapStrings(isThai: isThai);

    // Compute filtered list and stats once per build
    final filtered = _computeFiltered();
    final stats = _GuardStats.from(_guards);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              strings.subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: strings.refresh,
            onPressed: () {
              // TODO: Refresh guard locations from tracking API
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(strings, stats),
          _buildFilterChips(strings),
          Expanded(
            child: Stack(
              children: [
                _GuardMapLayer(
                  mapController: _mapController,
                  guards: filtered,
                  selectedGuardId: _selectedGuardId,
                  strings: strings,
                  onGuardTap: _onGuardTap,
                  onMapTap: () => setState(() => _selectedGuardId = null),
                ),
                _buildLegend(strings),
                _buildGuardListSheet(strings, filtered),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthorized(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.disabled),
            const SizedBox(height: 16),
            Text(
              isThai
                  ? 'คุณไม่มีสิทธิ์เข้าถึงหน้านี้'
                  : 'You do not have permission to access this page',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(LiveMapStrings strings, _GuardStats stats) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _buildStatCard(
            '${stats.total}',
            strings.totalOnMap,
            Icons.people_outline,
            AppColors.textPrimary,
            const Color(0xFFF1F5F9),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            '${stats.active}',
            strings.active,
            Icons.check_circle_outline,
            AppColors.primary,
            const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            '${stats.idle}',
            strings.idle,
            Icons.schedule,
            AppColors.warning,
            const Color(0xFFFFFBEB),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            '${stats.alert}',
            strings.alerts,
            Icons.warning_amber_rounded,
            AppColors.danger,
            const Color(0xFFFEF2F2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(LiveMapStrings strings) {
    final filters = [
      ('all', strings.filterAll),
      ('active', strings.filterActive),
      ('idle', strings.filterIdle),
      ('alert', strings.filterAlert),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filterStatus == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterStatus = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  f.$2,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend(LiveMapStrings strings) {
    return Positioned(
      bottom: 100,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.legend,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _buildLegendItem(AppColors.primary, strings.active),
            const SizedBox(height: 4),
            _buildLegendItem(AppColors.warning, strings.idle),
            const SizedBox(height: 4),
            _buildLegendItem(AppColors.danger, strings.filterAlert),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGuardListSheet(
    LiveMapStrings strings,
    List<DisplayGuard> guards,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.08,
      maxChildSize: 0.55,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.personnelList,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${guards.length} ${strings.guardsOnMap}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // List
              Expanded(
                child: guards.isEmpty
                    ? Center(
                        child: Text(
                          strings.noGuards,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: guards.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final guard = guards[index];
                          final isSelected = _selectedGuardId == guard.id;
                          return _buildGuardListItem(
                            guard,
                            strings,
                            isSelected,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuardListItem(
    DisplayGuard guard,
    LiveMapStrings strings,
    bool isSelected,
  ) {
    final color = statusColor(guard.status);
    final bgColor = _statusBgColor(guard.status);

    return GestureDetector(
      onTap: () => _onGuardTap(guard),
      child: Container(
        color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guard.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guard.location,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimeAgo(guard.lastUpdate, strings),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.disabled,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.disabled,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extracted map layer — only rebuilds when its inputs change.
// ─────────────────────────────────────────────────────────────────────────────

class _GuardMapLayer extends StatelessWidget {
  final MapController mapController;
  final List<DisplayGuard> guards;
  final String? selectedGuardId;
  final LiveMapStrings strings;
  final ValueChanged<DisplayGuard> onGuardTap;
  final VoidCallback onMapTap;

  const _GuardMapLayer({
    required this.mapController,
    required this.guards,
    required this.selectedGuardId,
    required this.strings,
    required this.onGuardTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(13.7363, 100.5318),
        initialZoom: 12,
        onTap: (_, _) => onMapTap(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.secureguard.mobile',
          // TODO: Switch to a commercial tile provider (Mapbox / Stadia / Thunderforest)
          // for production — OSM tile servers are not for heavy mobile app usage.
          // TODO: Add CachedTileProvider for disk caching to save bandwidth/battery.
        ),
        MarkerLayer(
          markers: guards.map((guard) {
            final isSelected = selectedGuardId == guard.id;
            return Marker(
              point: guard.position,
              width: isSelected ? 140 : 36,
              height: isSelected ? 80 : 36,
              child: GestureDetector(
                onTap: () => onGuardTap(guard),
                child: isSelected
                    ? _SelectedMarkerCallout(guard: guard, strings: strings)
                    : _MarkerDot(status: guard.status),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight marker dot — avoids rebuilding per frame.
// ─────────────────────────────────────────────────────────────────────────────

class _MarkerDot extends StatelessWidget {
  final GuardStatus status;
  const _MarkerDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _LiveMapScreenState.statusColor(status);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected marker popup callout — receives strings from parent (no duplicate).
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedMarkerCallout extends StatelessWidget {
  final DisplayGuard guard;
  final LiveMapStrings strings;
  const _SelectedMarkerCallout({
    required this.guard,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final color = _LiveMapScreenState.statusColor(guard.status);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                guard.name,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _LiveMapScreenState._formatTimeAgo(
                      guard.lastUpdate,
                      strings,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 6),
          painter: _TrianglePainter(color: Colors.white),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

/// Paints a small downward-pointing triangle for the popup callout.
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
