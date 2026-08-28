import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../services/report_service.dart';
import '../../widgets/pulsing_marker.dart';
import 'hazard_detail_sheet.dart';

// ── Marker color by severity (matches admin + report form) ──
Color severityColor(int severity, String status) {
  if (status == 'Critical') return AppColors.error;
  switch (severity) {
    case 5:
      return const Color(0xFFDC2626);
    case 4:
      return const Color(0xFFEA580C);
    case 3:
      return const Color(0xFFF59E0B);
    case 2:
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFF16A34A);
  }
}

// ── Icon by hazard type ──
IconData hazardIconFor(String type) {
  switch (type) {
    case 'Flood':
      return Icons.water_rounded;
    case 'Landslide':
      return Icons.landscape_rounded;
    case 'Fire':
      return Icons.local_fire_department_rounded;
    case 'Accident':
    case 'Road Accident':
      return Icons.car_crash_rounded;
    case 'Storm Surge':
      return Icons.waves_rounded;
    case 'Earthquake':
      return Icons.vibration_rounded;
    case 'Typhoon':
      return Icons.thunderstorm_rounded;
    case 'Flash Flood':
      return Icons.flood_rounded;
    default:
      return Icons.warning_rounded;
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _reportService = ReportService();

  Timer? _refreshTimer;
  bool _isSatellite = false;
  bool _showLegend = true;

  List<Report> _reports = [];
  bool _loading = true;
  String? _error;

  // User location (default to Balilihan center)
  final LatLng _userLocation = const LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  void initState() {
    super.initState();
    _loadReports();
    // Auto-refresh every 30 seconds so newly verified reports appear
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Fetch verified reports from the backend (same as the admin risk map).
  // silent = true skips the loading indicator (used by auto-refresh).
  Future<void> _loadReports({bool silent = false}) async {
    try {
      final reports = await _reportService.getVerifiedReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (silent)
        return; // don't disrupt the map on a background refresh failure
      if (!mounted) return;
      String msg;
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        msg = 'Your session expired. Please log out and log in again.';
      } else {
        msg = 'Failed to load hazards. Check your connection.';
      }
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  void _onHazardTapped(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HazardDetailSheet(report: report),
    );
  }

  void _centerOnUser() {
    _mapController.move(_userLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map (with pull-to-refresh) ──
          RefreshIndicator(
            onRefresh: () => _loadReports(),
            color: AppColors.primary,
            edgeOffset: MediaQuery.of(context).padding.top + 68,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userLocation,
                        initialZoom: AppConstants.defaultZoom,
                      ),
                      children: [
                        // Tile layer
                        TileLayer(
                          urlTemplate: _isSatellite
                              ? _satelliteTileUrl
                              : _osmTileUrl,
                          userAgentPackageName: 'com.balilihan.masid',
                        ),

                        // Hazard markers (real data)
                        MarkerLayer(
                          markers: _reports.map((r) {
                            return Marker(
                              point: LatLng(r.latitude, r.longitude),
                              width: 48,
                              height: 48,
                              child: GestureDetector(
                                onTap: () => _onHazardTapped(r),
                                child: PulsingMarker(
                                  color: severityColor(
                                    r.severity,
                                    r.statusName,
                                  ),
                                  icon: hazardIconFor(r.hazardName),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // User location marker
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation,
                              width: 36,
                              height: 36,
                              child: const _UserLocationDot(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Search bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.label,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Search barangay or hazard...',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 13,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Satellite toggle
                GestureDetector(
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSatellite
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSatellite
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.satellite_alt_rounded,
                      size: 20,
                      color: _isSatellite ? Colors.white : AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading / error banner ──
          if (_loading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading hazards...',
                      style: TextStyle(fontFamily: 'Sora', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null && !_loading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _loadReports();
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── My location button ──
          Positioned(
            bottom: 24,
            right: 16,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // ── Legend ──
          if (_showLegend)
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Severity',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _showLegend = false),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _legendRow(const Color(0xFFDC2626), 'Critical / 5'),
                    _legendRow(const Color(0xFFEA580C), 'High / 4'),
                    _legendRow(const Color(0xFFF59E0B), 'Moderate / 3'),
                    _legendRow(const Color(0xFF2563EB), 'Low / 2'),
                    _legendRow(const Color(0xFF16A34A), 'Minimal / 1'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── User location blue dot ──
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
