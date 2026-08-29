import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'report_service.dart';
import 'alert_service.dart';

/// Watches the user's location and alerts them when a verified hazard is
/// within [proximityRadiusMeters]. Foreground-only (runs while the app is open).
///
/// - Fires a local notification (popup)
/// - Creates a backend alert (so it shows in the Alerts tab)
/// - Alerts once per hazard (won't re-notify while you stay nearby)
class ProximityService {
  ProximityService._();
  static final ProximityService instance = ProximityService._();

  static const double proximityRadiusMeters = 100.0;
  static const int _distanceFilterMeters = 15; // update when user moves ~15m

  final _reportService = ReportService();
  final _alertService = AlertService();
  final _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSub;
  bool _started = false;
  bool _notifInitialized = false;

  // Hazard IDs we've already alerted the user about (this session)
  final Set<int> _alertedHazardIDs = {};

  // Latest known verified hazards (refreshed periodically by the map)
  List<Report> _hazards = [];

  // Called by the map when it (re)loads verified hazards
  void updateHazards(List<Report> hazards) {
    _hazards = hazards;
  }

  Future<void> _initNotifications() async {
    if (_notifInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _notifications.initialize(initSettings);

    // Android notification channel
    const channel = AndroidNotificationChannel(
      'hazard_proximity',
      'Nearby Hazard Alerts',
      description: 'Warns you when a verified hazard is nearby',
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _notifInitialized = true;
  }

  /// Start watching location + proximity. Safe to call multiple times.
  Future<void> start() async {
    if (_started) return;

    // Ensure location permission (foreground)
    final ok = await _ensurePermission();
    if (!ok) return;

    await _initNotifications();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
      ),
    ).listen(_onPosition, onError: (_) {});

    _started = true;
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _started = false;
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  void _onPosition(Position pos) {
    for (final h in _hazards) {
      if (_alertedHazardIDs.contains(h.reportID)) continue;

      final meters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        h.latitude,
        h.longitude,
      );

      if (meters <= proximityRadiusMeters) {
        _alertedHazardIDs.add(h.reportID); // once per hazard
        _fireAlert(h, meters);
      }
    }
  }

  Future<void> _fireAlert(Report hazard, double meters) async {
    final distanceText = '${meters.round()}m away';
    final title = '${hazard.hazardName} Nearby';
    final message =
        'A verified ${hazard.hazardName.toLowerCase()} is about $distanceText. Stay alert and stay safe.';

    // 1. Local popup notification
    try {
      const androidDetails = AndroidNotificationDetails(
        'hazard_proximity',
        'Nearby Hazard Alerts',
        channelDescription: 'Warns you when a verified hazard is nearby',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notifications.show(hazard.reportID, title, message, details);
    } catch (_) {
      // notification failure shouldn't block the backend alert
    }

    // 2. Create a backend alert so it shows in the Alerts tab
    try {
      await _alertService.createAlert(
        hazardID: hazard.reportID,
        type: 'hazard',
        title: title,
        message: message,
      );
    } catch (_) {
      // ignore backend failure; the popup already warned the user
    }
  }
}
