import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../services/report_service.dart';
import '../../services/proximity_service.dart';
import '../../services/establishment_service.dart';
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
  // Matches the report form's hazard icon set (all 17 types)
  switch (type) {
    case 'Flood':
      return Icons.water_rounded;
    case 'Landslide':
      return Icons.landscape_rounded;
    case 'Earthquake':
      return Icons.vibration_rounded;
    case 'Fire':
      return Icons.local_fire_department_rounded;
    case 'Typhoon':
      return Icons.thunderstorm_rounded;
    case 'Storm Surge':
      return Icons.waves_rounded;
    case 'Drought':
      return Icons.wb_sunny_rounded;
    case 'Sinkhole':
      return Icons.circle_outlined;
    case 'Accident':
    case 'Road Accident':
      return Icons.car_crash_rounded;
    case 'Structural Collapse':
      return Icons.domain_disabled_rounded;
    case 'Flash Flood':
      return Icons.flood_rounded;
    case 'Soil Erosion':
      return Icons.terrain_rounded;
    case 'Power Outage':
      return Icons.power_off_rounded;
    case 'Water Contamination':
      return Icons.water_drop_rounded;
    case 'Fallen Tree':
      return Icons.park_rounded;
    case 'Animal Hazard':
      return Icons.pets_rounded;
    default:
      return Icons.warning_rounded;
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// ── Establishment icon by type (matches the admin map) ──
IconData establishmentIconFor(String type) {
  switch (type) {
    case 'School':
      return Icons.school_rounded;
    case 'Health Facility':
      return Icons.local_hospital_rounded;
    case 'Government Hall':
      return Icons.account_balance_rounded;
    case 'Place of Worship':
      return Icons.church_rounded;
    case 'Social Facility':
      return Icons.groups_rounded;
    case 'Market':
      return Icons.storefront_rounded;
    case 'Evacuation Center':
      return Icons.safety_divider_rounded;
    case 'Library':
      return Icons.menu_book_rounded;
    case 'Childcare':
      return Icons.child_care_rounded;
    default:
      return Icons.place_rounded;
  }
}

Color establishmentColorFor(String category) {
  switch (category) {
    case 'Education':
      return const Color(0xFF2563EB);
    case 'Health':
      return const Color(0xFFDC2626);
    case 'Government':
      return const Color(0xFF475569);
    case 'Community':
      return const Color(0xFF7C3AED);
    case 'Commercial':
      return const Color(0xFFD97706);
    case 'Emergency':
      return const Color(0xFF0891B2);
    case 'Public':
      return const Color(0xFF92400E);
    default:
      return const Color(0xFF64748B);
  }
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _reportService = ReportService();
  final _establishmentService = EstablishmentService();

  Timer? _refreshTimer;
  bool _isSatellite = false;
  bool _showLegend = true;
  bool _showEstablishments = false;
  List<Establishment> _establishments = [];

  List<Report> _reports = [];
  bool _loading = true;
  String? _error;

  // User location — starts at Balilihan center, updated to real GPS on load
  LatLng _userLocation = const LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );
  bool _hasRealLocation = false;
  final Dio _dio = Dio(); // plain client for the external OSRM routing API

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadEstablishments();
    _initLocation();
    // Auto-refresh every 30 seconds so newly verified reports appear
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadReports(silent: true);
    });
  }

  bool _locating = false;

  // Get the user's real location for the map dot + start proximity watching.
  // `moveMap` centers the map on the user once found.
  Future<void> _initLocation({
    bool moveMap = false,
    bool showFeedback = false,
  }) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      // 1. Location services on?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showFeedback && mounted) {
          _snack(
            'Location is off. Please enable Location/GPS in your device settings.',
          );
          await Geolocator.openLocationSettings();
        }
        return;
      }

      // 2. Permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (showFeedback && mounted) {
          _snack(
            'Location permission is permanently denied. Enable it in app settings.',
          );
          await Geolocator.openAppSettings();
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (showFeedback && mounted) _snack('Location permission denied.');
        return;
      }

      // 3. Get a position — try last-known first (instant), then a fresh fix
      //    with a timeout so it can't hang forever.
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _userLocation = LatLng(pos!.latitude, pos.longitude);
          _hasRealLocation = true;
        });
        if (moveMap) _mapController.move(_userLocation, 16);
      }

      // Fresh, accurate fix (may take a moment)
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (_) {
        // fall back to medium accuracy if high times out
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (_) {
          pos = pos; // keep last-known if both fail
        }
      }

      if (pos != null && mounted) {
        setState(() {
          _userLocation = LatLng(pos!.latitude, pos.longitude);
          _hasRealLocation = true;
        });
        if (moveMap) _mapController.move(_userLocation, 16);
      } else if (showFeedback && mounted && !_hasRealLocation) {
        _snack('Could not get your location. Try again in an open area.');
      }

      // Start proximity watching (foreground) — alerts on hazards within 100m
      await ProximityService.instance.start();
    } catch (e) {
      if (showFeedback && mounted) _snack('Location error. Please try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // Button handler: locate me + center the map on my position.
  Future<void> _locateMe() async {
    await _initLocation(moveMap: true, showFeedback: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Fetch verified reports from the backend (same as the admin risk map).
  // silent = true skips the loading indicator (used by auto-refresh).
  // Show a small sheet with the establishment's name + type when tapped.
  void _onEstablishmentTapped(Establishment e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: establishmentColorFor(
                  e.category,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                establishmentIconFor(e.type),
                color: establishmentColorFor(e.category),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.type,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fetch establishments once (schools, health, churches, halls, etc.)
  Future<void> _loadEstablishments() async {
    try {
      final list = await _establishmentService.getEstablishments();
      if (!mounted) return;
      setState(() => _establishments = list);
    } catch (_) {
      // non-fatal; establishments just won't show
    }
  }

  Future<void> _loadReports({bool silent = false}) async {
    try {
      final reports = await _reportService.getVerifiedReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _error = null;
      });
      // Give the proximity watcher the latest verified hazards to check against
      ProximityService.instance.updateHazards(reports);
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

  // Find the nearest establishment flagged as an evacuation center, then
  // open directions to it in the device's maps app.
  // ── Nearest establishment routing (in-app, follows roads via OSRM) ──
  List<LatLng> _routePoints = []; // the drawn route polyline
  Establishment? _routeDest; // the destination establishment
  double _routeDistanceM = 0; // route distance (metres)
  bool _routing = false;

  // Find the nearest establishment of a kind, then draw a road route to it.
  //  kind: "evacuation" -> flagged evac centers; "medical" -> health facilities.
  Future<void> _routeToNearest(String kind) async {
    List<Establishment> pool;
    if (kind == "evacuation") {
      pool = _establishments.where((e) => e.isEvacuationCenter).toList();
    } else {
      pool = _establishments.where((e) => e.type == "Health Facility").toList();
    }

    if (pool.isEmpty) {
      _snack(
        kind == "evacuation"
            ? 'No evacuation centers available'
            : 'No medical centers available',
      );
      return;
    }

    // Pick the closest by straight-line distance (fast pre-filter).
    const distance = Distance();
    Establishment? nearest;
    double best = double.infinity;
    for (final e in pool) {
      final d = distance.as(
        LengthUnit.Meter,
        _userLocation,
        LatLng(e.latitude, e.longitude),
      );
      if (d < best) {
        best = d;
        nearest = e;
      }
    }
    if (nearest == null) return;

    setState(() => _routing = true);
    try {
      // Ask OSRM for the road route from the user to the destination.
      final route = await _fetchRoute(
        _userLocation,
        LatLng(nearest.latitude, nearest.longitude),
      );
      if (!mounted) return;
      setState(() {
        _routeDest = nearest;
        _routePoints = route.$1.isNotEmpty
            ? route.$1
            : [
                _userLocation,
                LatLng(nearest!.latitude, nearest.longitude),
              ]; // fallback: straight line
        _routeDistanceM = route.$2 > 0 ? route.$2 : best;
      });

      // Fit the map to show the whole route.
      _fitRoute();

      // Show a small info card.
      _showRouteCard(kind);
    } catch (e) {
      if (!mounted) return;
      // Fallback: straight line if routing fails.
      setState(() {
        _routeDest = nearest;
        _routePoints = [
          _userLocation,
          LatLng(nearest!.latitude, nearest.longitude),
        ];
        _routeDistanceM = best;
      });
      _fitRoute();
      _showRouteCard(kind);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  // Call the free OSRM public API for a driving route.
  // Returns (list of points, distance in metres).
  Future<(List<LatLng>, double)> _fetchRoute(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    final res = await _dio.getUri(Uri.parse(url));
    final data = res.data;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return (<LatLng>[], 0.0);
    final route = routes[0];
    final dist = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final coords = route['geometry']['coordinates'] as List;
    final pts = coords
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
    return (pts, dist);
  }

  void _fitRoute() {
    if (_routePoints.length < 2) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _routeDest = null;
      _routeDistanceM = 0;
    });
  }

  void _showRouteCard(String kind) {
    final dest = _routeDest;
    if (dest == null) return;
    final isEvac = kind == "evacuation";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (isEvac ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEvac
                    ? Icons.safety_divider_rounded
                    : Icons.local_hospital_rounded,
                color: isEvac ? AppColors.success : AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dest.name,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  Text(
                    '${isEvac ? (dest.evacType ?? "Evacuation") + " Evacuation Center" : "Medical Center"} · ${(_routeDistanceM / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom sheet: choose Evacuation or Medical.
  void _openNearestChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12, top: 2),
              child: Text(
                'Find the nearest…',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
            ),
            _chooserTile(
              icon: Icons.safety_divider_rounded,
              color: AppColors.success,
              label: 'Evacuation Center',
              onTap: () {
                Navigator.pop(context);
                _routeToNearest("evacuation");
              },
            ),
            const SizedBox(height: 8),
            _chooserTile(
              icon: Icons.local_hospital_rounded,
              color: AppColors.error,
              label: 'Medical Center',
              onTap: () {
                Navigator.pop(context);
                _routeToNearest("medical");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chooserTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
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

                        // Establishment markers (schools, churches, health, etc.)
                        if (_showEstablishments)
                          MarkerLayer(
                            markers: _establishments.map((e) {
                              return Marker(
                                point: LatLng(e.latitude, e.longitude),
                                width: 30,
                                height: 30,
                                child: GestureDetector(
                                  onTap: () => _onEstablishmentTapped(e),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: establishmentColorFor(e.category),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x40000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      establishmentIconFor(e.type),
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        // Route polyline (to nearest evacuation / medical)
                        if (_routePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5,
                                color: AppColors.primary,
                                borderStrokeWidth: 2,
                                borderColor: Colors.white,
                              ),
                            ],
                          ),

                        // Destination marker for the route
                        if (_routeDest != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _routeDest!.latitude,
                                  _routeDest!.longitude,
                                ),
                                width: 40,
                                height: 40,
                                child: Icon(
                                  _routeDest!.isEvacuationCenter
                                      ? Icons.safety_divider_rounded
                                      : Icons.local_hospital_rounded,
                                  color: _routeDest!.isEvacuationCenter
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 34,
                                ),
                              ),
                            ],
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

                const SizedBox(width: 10),

                // Establishments toggle
                GestureDetector(
                  onTap: () => setState(
                    () => _showEstablishments = !_showEstablishments,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _showEstablishments
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showEstablishments
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
                      Icons.storefront_rounded,
                      size: 20,
                      color: _showEstablishments
                          ? Colors.white
                          : AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Locate me button (right side, above the evac button) ──
          Positioned(
            right: 16,
            bottom: 88,
            child: GestureDetector(
              onTap: _locateMe,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _locating
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _hasRealLocation
                            ? Icons.my_location_rounded
                            : Icons.location_searching_rounded,
                        color: _hasRealLocation
                            ? AppColors.primary
                            : AppColors.secondary,
                        size: 22,
                      ),
              ),
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
          // ── Find Nearest button (Evacuation / Medical) — bottom, own position ──
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _routing ? null : _openNearestChooser,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _routing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.near_me_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Find Nearest Center',
                                      style: TextStyle(
                                        fontFamily: 'Sora',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (_routePoints.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _clearRoute,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.secondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
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
