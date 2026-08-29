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

  // Hazard IDs the user is CURRENTLY within range of.
  // We alert only when a hazard ENTERS this set (outside -> inside),
  // not repeatedly while the user stays nearby. This prevents alert spam.
  final Set<int> _hazardsInRange = {};

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
      final meters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        h.latitude,
        h.longitude,
      );

      final inRangeNow = meters <= proximityRadiusMeters;
      final wasInRange = _hazardsInRange.contains(h.reportID);

      if (inRangeNow && !wasInRange) {
        // ENTER: user just came within range — alert once
        _hazardsInRange.add(h.reportID);
        _fireAlert(h, meters);
      } else if (!inRangeNow && wasInRange) {
        // EXIT: user left the area — re-arm so a future re-entry alerts again
        _hazardsInRange.remove(h.reportID);
      }
      // Still in range (or still out of range): do nothing — no repeat alert
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
    //    (backend deduplicates — won't create if an unread one already exists)
    try {
      await _alertService.createHazardAlert(
        hazardID: hazard.reportID,
        title: title,
        message: message,
      );
    } catch (_) {
      // ignore backend failure; the popup already warned the user
    }
  }
}
