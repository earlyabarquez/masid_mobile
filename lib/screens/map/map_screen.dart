import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  // Plain client for the external OSRM routing API. Timeouts keep the
  // "finding route" spinner from hanging forever on a bad connection.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // ── Live position tracking ──
  StreamSubscription<Position>? _trackSub; // always-on while the map is open
  bool _trackPrecise = false; // true = high-rate GPS (only while navigating)
  double _heading = 0; // degrees clockwise from north
  bool _followUser = false; // camera follows the user while navigating

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

      // Keep the blue dot (and heading) live from now on.
      _startTracking(precise: _navigating);

      // Start proximity watching (foreground) — alerts on hazards within 100m
      await ProximityService.instance.start();
    } catch (e) {
      if (showFeedback && mounted) _snack('Location error. Please try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Live tracking ──
  // One position stream drives both the blue dot and navigation.
  // Normal mode is battery-friendly; navigation switches to high-rate GPS.
  void _startTracking({bool precise = false}) {
    if (_trackSub != null && _trackPrecise == precise) return;
    _trackSub?.cancel();
    _trackPrecise = precise;
    _trackSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: precise
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.high,
        // Small filters = the dot/camera move as you move.
        // (1 m while navigating, 3 m otherwise.)
        distanceFilter: precise ? 1 : 3,
      ),
    ).listen(_onTrackPosition, onError: (_) {});
  }

  void _onTrackPosition(Position pos) {
    if (!mounted) return;
    final here = LatLng(pos.latitude, pos.longitude);

    // GPS heading is noisy when standing still — only trust it while moving.
    if (pos.speed > 1.0 && pos.heading >= 0) _heading = pos.heading;

    setState(() {
      _userLocation = here;
      _hasRealLocation = true;
    });

    if (_navigating) {
      _updateNavProgress(here);
      // Keep the camera on the user (heading-up) unless they panned away.
      if (_followUser) {
        _mapController.moveAndRotate(here, 17, -_heading);
      }
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
    _trackSub?.cancel();
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

  // ── Nearest establishment routing (in-app, follows roads via OSRM) ──
  List<LatLng> _routePoints = []; // the drawn route polyline
  List<double> _cumDist = []; // cumulative metres along _routePoints
  Establishment? _routeDest; // the destination establishment
  String _navKind = 'evacuation'; // "evacuation" | "medical" (for rerouting)
  double _routeDistanceM = 0; // route distance (metres)
  double _routeDurationS = 0; // OSRM driving time for the whole route
  bool _routing = false;

  // ── Live navigation state ──
  bool _navigating = false; // turn-by-turn mode active
  List<_NavStep> _navSteps = []; // turn-by-turn instructions
  List<double> _stepAlong = []; // metres along the route of each maneuver
  int _currentStep = 0; // index of the upcoming maneuver
  int _routeSeg = 0; // index of the route segment the user is on
  double _distToNextTurn = 0; // metres to the next maneuver
  double _distRemaining = 0; // metres remaining along the route
  double _etaSeconds = 0; // estimated time remaining
  int _offRouteCount = 0; // consecutive off-route position updates
  bool _rerouting = false;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  // Find the nearest establishment of a kind, then draw a road route to it.
  //  kind: "evacuation" -> flagged evac centers; "medical" -> health facilities.
  Future<void> _routeToNearest(String kind) async {
    // Never route from the default map center — wait for a real GPS fix.
    if (!_hasRealLocation) {
      if (_locating) {
        _snack('Getting your location… try again in a moment.');
        return;
      }
      await _initLocation(moveMap: true, showFeedback: true);
      if (!_hasRealLocation) return;
    }

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

    // Pre-filter: the 5 closest by straight-line distance (fast).
    const distance = Distance();
    double straight(Establishment e) => distance.as(
      LengthUnit.Meter,
      _userLocation,
      LatLng(e.latitude, e.longitude),
    );
    final ranked = [...pool]
      ..sort((a, b) => straight(a).compareTo(straight(b)));
    final candidates = ranked.take(5).toList();

    setState(() => _routing = true);
    try {
      // Pick the one that is actually nearest by ROAD (falls back to the
      // straight-line winner if the routing service is unreachable).
      final nearest = await _nearestByRoad(candidates) ?? candidates.first;
      await _loadRouteTo(nearest, kind);
      if (!mounted) return;
      _fitRoute();
      _showRouteCard(kind);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  // Ask OSRM's table service for road distances to all candidates at once.
  Future<Establishment?> _nearestByRoad(List<Establishment> candidates) async {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    try {
      final coords = [
        '${_userLocation.longitude},${_userLocation.latitude}',
        ...candidates.map((e) => '${e.longitude},${e.latitude}'),
      ].join(';');
      final url =
          'https://router.project-osrm.org/table/v1/driving/$coords'
          '?sources=0&annotations=distance';
      final res = await _dio.getUri(Uri.parse(url));
      final row = (res.data['distances'] as List).first as List;
      Establishment? best;
      double bestD = double.infinity;
      for (int i = 0; i < candidates.length; i++) {
        final v = row[i + 1]; // index 0 is the user themself
        if (v is num && v < bestD) {
          bestD = v.toDouble();
          best = candidates[i];
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  // Fetch a road route to [dest] and store it (falls back to a straight line).
  Future<void> _loadRouteTo(
    Establishment dest,
    String kind, {
    LatLng? from,
  }) async {
    final start = from ?? _userLocation;
    final end = LatLng(dest.latitude, dest.longitude);

    _RouteResult? r;
    try {
      r = await _fetchRoute(start, end);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;

    final pts = (r != null && r.points.length >= 2) ? r.points : [start, end];
    final cum = _buildCumulative(pts);
    final steps = r?.steps ?? <_NavStep>[];

    setState(() {
      _routeDest = dest;
      _navKind = kind;
      _routePoints = pts;
      _cumDist = cum;
      _routeDistanceM = cum.last;
      _routeDurationS = r?.duration ?? 0;
      _navSteps = steps;
      _stepAlong = steps
          .map(
            (s) => _matchToRoute(s.location, pts: pts, cum: cum)?.alongM ?? 0.0,
          )
          .toList();
      _currentStep = steps.length > 1 ? 1 : 0; // step 0 is "depart"
      _routeSeg = 0;
      _offRouteCount = 0;
    });
  }

  // ── Start live turn-by-turn navigation ──
  Future<void> _startNavigation() async {
    if (_routePoints.length < 2) return;
    setState(() {
      _navigating = true;
      _followUser = true;
      _offRouteCount = 0;
      _distRemaining = _routeDistanceM;
      _currentStep = _navSteps.length > 1 ? 1 : 0;
    });

    // Switch to high-rate GPS for navigation.
    _startTracking(precise: true);
    _updateNavProgress(_userLocation);
    _mapController.moveAndRotate(_userLocation, 17, -_heading);
  }

  void _stopNavigation({bool fit = true}) {
    setState(() {
      _navigating = false;
      _followUser = false;
      _rerouting = false;
    });
    // Back to battery-friendly tracking (only if tracking was running).
    if (_trackSub != null) _startTracking();
    _mapController.rotate(0);
    if (fit) _fitRoute();
  }

  // Re-center on the user and resume following (after they panned away).
  void _recenter() {
    setState(() => _followUser = true);
    _mapController.moveAndRotate(_userLocation, 17, -_heading);
  }

  // Match the user to the route: how far off it they are, which segment they
  // are on, and how many metres along the route they've travelled.
  _RouteMatch? _matchToRoute(LatLng p, {List<LatLng>? pts, List<double>? cum}) {
    final points = pts ?? _routePoints;
    final cumulative = cum ?? _cumDist;
    if (points.length < 2 || cumulative.length != points.length) return null;

    const mLat = 111320.0;
    final mLng = 111320.0 * math.cos(p.latitude * math.pi / 180);

    double best = double.infinity;
    int bestSeg = 0;
    double bestAlong = 0;

    for (int i = 0; i < points.length - 1; i++) {
      // Segment endpoints in metres, relative to p (p is the origin).
      final ax = (points[i].longitude - p.longitude) * mLng;
      final ay = (points[i].latitude - p.latitude) * mLat;
      final bx = (points[i + 1].longitude - p.longitude) * mLng;
      final by = (points[i + 1].latitude - p.latitude) * mLat;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;

      double t = 0;
      if (len2 > 0) {
        t = (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0).toDouble();
      }
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);

      if (d < best) {
        best = d;
        bestSeg = i;
        bestAlong = cumulative[i] + t * (cumulative[i + 1] - cumulative[i]);
      }
    }
    return _RouteMatch(best, bestSeg, bestAlong);
  }

  List<double> _buildCumulative(List<LatLng> pts) {
    const distance = Distance();
    final cum = <double>[0];
    for (int i = 1; i < pts.length; i++) {
      cum.add(cum.last + distance.as(LengthUnit.Meter, pts[i - 1], pts[i]));
    }
    return cum;
  }

  // Update the upcoming step, distances, ETA — and reroute if the user strays.
  void _updateNavProgress(LatLng here) {
    if (!_navigating || _routeDest == null) return;
    const distance = Distance();

    final destPoint = LatLng(_routeDest!.latitude, _routeDest!.longitude);
    final straightToDest = distance.as(LengthUnit.Meter, here, destPoint);
    final match = _matchToRoute(here);

    if (match != null) {
      _routeSeg = match.segIndex;
      final total = _cumDist.last;
      _distRemaining = math.max(0.0, total - match.alongM);
      _etaSeconds = (_routeDurationS > 0 && total > 0)
          ? _routeDurationS * (_distRemaining / total)
          : 0;
    } else {
      _distRemaining = straightToDest;
    }

    // Arrived? (close in a straight line AND close along the route)
    if (straightToDest < 25 && _distRemaining < 60) {
      _snack('You have arrived at ${_routeDest?.name ?? "your destination"}');
      _stopNavigation();
      return;
    }

    // Off-route detection (needs a few consecutive readings to ignore GPS jitter)
    if (match != null && match.offRouteM > 40) {
      _offRouteCount++;
    } else {
      _offRouteCount = 0;
    }
    if (_offRouteCount >= 3 &&
        !_rerouting &&
        DateTime.now().difference(_lastReroute) > const Duration(seconds: 10)) {
      _reroute(here);
    }

    // Advance to the next maneuver once we're within ~10 m of the current one.
    if (match != null &&
        _navSteps.isNotEmpty &&
        _stepAlong.length == _navSteps.length) {
      var next = _currentStep;
      while (next < _navSteps.length - 1 &&
          _stepAlong[next] <= match.alongM + 10) {
        next++;
      }
      if (next != _currentStep) {
        _currentStep = next;
        HapticFeedback.mediumImpact(); // tactile cue for the next instruction
      }
      _distToNextTurn = math.max(0.0, _stepAlong[_currentStep] - match.alongM);
    }

    setState(() {});
  }

  // User left the route — fetch a fresh one from where they are now.
  Future<void> _reroute(LatLng from) async {
    final dest = _routeDest;
    if (dest == null) return;
    _rerouting = true;
    _lastReroute = DateTime.now();
    if (mounted) setState(() {});
    await _loadRouteTo(dest, _navKind, from: from);
    _offRouteCount = 0;
    _rerouting = false;
    if (mounted) setState(() {});
  }

  // Call the free OSRM public API for a driving route (points, distance,
  // duration and turn-by-turn steps).
  Future<_RouteResult> _fetchRoute(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true';
    final res = await _dio.getUri(Uri.parse(url));
    final data = res.data;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return _RouteResult(points: [], distance: 0, duration: 0, steps: []);
    }
    final route = routes[0];
    final dist = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final dur = (route['duration'] as num?)?.toDouble() ?? 0.0;
    final coords = route['geometry']['coordinates'] as List;
    final pts = coords
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();

    // Parse turn-by-turn steps from the first leg.
    final steps = <_NavStep>[];
    final legs = route['legs'] as List?;
    if (legs != null && legs.isNotEmpty) {
      final legSteps = legs[0]['steps'] as List?;
      if (legSteps != null) {
        for (final s in legSteps) {
          final maneuver = s['maneuver'] ?? {};
          final loc = maneuver['location'] as List?; // [lng, lat]
          final type = (maneuver['type'] ?? '').toString();
          final modifier = (maneuver['modifier'] ?? '').toString();
          final name = (s['name'] ?? '').toString();
          final stepDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
          steps.add(
            _NavStep(
              instruction: _instructionText(type, modifier, name),
              icon: _maneuverIcon(type, modifier),
              location: (loc != null && loc.length >= 2)
                  ? LatLng(
                      (loc[1] as num).toDouble(),
                      (loc[0] as num).toDouble(),
                    )
                  : from,
              distance: stepDist,
            ),
          );
        }
      }
    }
    return _RouteResult(
      points: pts,
      distance: dist,
      duration: dur,
      steps: steps,
    );
  }

  // Build a readable instruction from the OSRM maneuver.
  String _instructionText(String type, String modifier, String road) {
    final on = road.isNotEmpty ? ' onto $road' : '';
    switch (type) {
      case 'depart':
        return 'Head out' + (road.isNotEmpty ? ' on $road' : '');
      case 'arrive':
        return 'Arrive at your destination';
      case 'turn':
        return 'Turn ${modifier.isEmpty ? '' : modifier}$on'.trim();
      case 'continue':
        return 'Continue ${modifier}$on'.trim();
      case 'merge':
        return 'Merge ${modifier}$on'.trim();
      case 'roundabout':
      case 'rotary':
        return 'Take the roundabout$on';
      case 'fork':
        return 'Keep ${modifier}$on'.trim();
      case 'end of road':
        return 'Turn ${modifier}$on'.trim();
      default:
        return 'Continue${road.isNotEmpty ? ' on $road' : ''}';
    }
  }

  IconData _maneuverIcon(String type, String modifier) {
    if (type == 'arrive') return Icons.place_rounded;
    if (type == 'depart') return Icons.my_location_rounded;
    if (type == 'roundabout' || type == 'rotary')
      return Icons.roundabout_right_rounded;
    if (modifier.contains('left')) return Icons.turn_left_rounded;
    if (modifier.contains('right')) return Icons.turn_right_rounded;
    if (modifier.contains('straight') || type == 'continue')
      return Icons.straight_rounded;
    return Icons.navigation_rounded;
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
    if (_navigating) _stopNavigation(fit: false);
    setState(() {
      _routePoints = [];
      _cumDist = [];
      _routeDest = null;
      _routeDistanceM = 0;
      _routeDurationS = 0;
      _navSteps = [];
      _stepAlong = [];
    });
  }

  // While navigating, draw only the part of the route still ahead of the user.
  List<LatLng> get _visibleRoute {
    if (!_navigating || _routePoints.length < 2) return _routePoints;
    final i = math.min(math.max(_routeSeg, 0), _routePoints.length - 2);
    return [_userLocation, ..._routePoints.sublist(i + 1)];
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  String _fmtEta(double seconds) {
    final mins = (seconds / 60).ceil();
    if (mins < 1) return '< 1 min';
    if (mins >= 60) return '${mins ~/ 60} h ${mins % 60} min';
    return '$mins min';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startNavigation();
                },
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
    final hasSteps = _navSteps.isNotEmpty && _currentStep < _navSteps.length;

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
                        // If the user drags the map during navigation, stop
                        // following them (a Recenter button appears).
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture && _navigating && _followUser) {
                            setState(() => _followUser = false);
                          }
                        },
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
                        // rotate: true keeps icons upright when the map rotates
                        // (heading-up navigation).
                        if (_showEstablishments)
                          MarkerLayer(
                            markers: _establishments.map((e) {
                              return Marker(
                                point: LatLng(e.latitude, e.longitude),
                                width: 30,
                                height: 30,
                                rotate: true,
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

                        // Route polyline (to nearest evacuation / medical).
                        // While navigating, only the part still ahead is drawn.
                        if (_visibleRoute.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _visibleRoute,
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
                                rotate: true,
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
                              rotate: true,
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

                        // User location marker: blue dot normally, a heading
                        // arrow while navigating. The arrow rotates WITH the map
                        // (rotate: false) so it always points where you're heading.
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation,
                              width: 44,
                              height: 44,
                              rotate: false,
                              child: _navigating
                                  ? _NavArrow(heading: _heading)
                                  : const _UserLocationDot(),
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

          // ── Turn-by-turn directions panel (top, while navigating) ──
          if (_navigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      hasSteps
                          ? _navSteps[_currentStep].icon
                          : Icons.navigation_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasSteps
                                ? _navSteps[_currentStep].instruction
                                : 'Head to ${_routeDest?.name ?? "your destination"}',
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasSteps
                                ? 'In ${_fmtDist(_distToNextTurn)}'
                                : '${_fmtDist(_distRemaining)} to destination',
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _stopNavigation,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── "Rerouting…" chip (under the directions panel) ──
          if (_navigating && _rerouting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 108,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Rerouting…',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Distance / ETA pill (bottom, while navigating) ──
          if (_navigating)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_etaSeconds > 0 ? "${_fmtEta(_etaSeconds)} · " : ""}'
                    '${_fmtDist(_distRemaining)} • ${_routeDest?.name ?? ""}',
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                ),
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

          // ── Legend (hidden while navigating so it doesn't crowd the pill) ──
          if (_showLegend && !_navigating)
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
          // ── Find Nearest button (icon only) — above the locate button ──
          Positioned(
            right: 16,
            bottom: 146,
            child: GestureDetector(
              onTap: _routing ? null : _openNearestChooser,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _routing
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.near_me_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),

          // ── Clear route button (only when a route is shown) ──
          if (_routePoints.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 202,
              child: GestureDetector(
                onTap: _clearRoute,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
              ),
            ),

          // ── Recenter button (navigating, but the user panned the map away) ──
          if (_navigating && !_followUser)
            Positioned(
              right: 16,
              bottom: 258,
              child: GestureDetector(
                onTap: _recenter,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
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

// ── Heading arrow shown while navigating ──
class _NavArrow extends StatelessWidget {
  final double heading; // degrees clockwise from north

  const _NavArrow({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: heading * math.pi / 180,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// A single turn-by-turn navigation step.
class _NavStep {
  final String instruction;
  final IconData icon;
  final LatLng location; // the maneuver point
  final double distance; // metres for this step

  _NavStep({
    required this.instruction,
    required this.icon,
    required this.location,
    required this.distance,
  });
}

// What OSRM returned for one route.
class _RouteResult {
  final List<LatLng> points;
  final double distance; // metres
  final double duration; // seconds (driving)
  final List<_NavStep> steps;

  _RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}

// Where the user is relative to the route.
class _RouteMatch {
  final double offRouteM; // distance from the route line
  final int segIndex; // route segment the user is closest to
  final double alongM; // metres travelled along the route

  _RouteMatch(this.offRouteM, this.segIndex, this.alongM);
}
