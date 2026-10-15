import 'dart:async';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'report_service.dart';
import 'alert_service.dart';
import 'alert_watcher.dart';
import 'location_sync_service.dart';

/// Watches the user's location and alerts them when a verified hazard is
/// within [proximityRadiusMeters]. Foreground-only (runs while the app is open).
///
/// - Fires a local notification (popup with sound + vibration)
/// - Creates a backend alert (so it shows in the Alerts tab)
/// - Alerts once per hazard (won't re-notify while you stay nearby)
/// - Reports the user's location to the backend so it can alert them when a
///   report is verified near them, and shows those alerts too (AlertWatcher)
class ProximityService {
  ProximityService._();
  static final ProximityService instance = ProximityService._();

  static const double proximityRadiusMeters = 100.0;
  static const int _distanceFilterMeters = 15; // update when user moves ~15m

  // Android channel settings can't be changed once a channel exists, so the
  // id is versioned: bump it if you change sound/vibration/importance again.
  static const String _channelId = 'hazard_nearby_v2';
  static const String _channelName = 'Nearby Hazard Alerts';
  static const String _channelDesc =
      'Warns you when a verified hazard is nearby';

  // wait, buzz, pause, buzz, pause, long buzz (ms)
  static final Int64List _vibrationPattern = Int64List.fromList([
    0,
    500,
    250,
    500,
    250,
    800,
  ]);

  final _alertService = AlertService();
  final _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSub;
  bool _started = false;
  bool _notifInitialized = false;
  Position? _lastPosition;

  // Hazard IDs the user is CURRENTLY within range of (or was already warned
  // about). We alert only when a hazard ENTERS this set (outside -> inside),
  // not repeatedly while the user stays nearby. This prevents alert spam.
  final Set<int> _hazardsInRange = {};

  // Latest known verified hazards (refreshed periodically by the map)
  List<Report> _hazards = [];

  // Called by the map when it (re)loads verified hazards. Checks right away
  // against the last known position, so a hazard that was just verified near a
  // user who is standing still alerts immediately (not after they next move).
  void updateHazards(List<Report> hazards) {
    _hazards = hazards;
    final pos = _lastPosition;
    if (pos != null) _checkHazards(pos);
  }

  /// True if this hazard has already been warned about (or is in range).
  bool hasAlerted(int hazardID) => _hazardsInRange.contains(hazardID);

  /// Mark a hazard as already warned about (prevents a duplicate popup).
  void markAlerted(int hazardID) => _hazardsInRange.add(hazardID);

  Future<void> _initNotifications() async {
    if (_notifInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _notifications.initialize(initSettings);

    // Android notification channel: loud (max importance), with sound + vibration
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _notifInitialized = true;
  }

  /// Show a notification with sound + vibration. (If the phone is on silent,
  /// the OS plays the vibration only.)
  Future<void> notify({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _initNotifications();
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notifications.show(id, title, body, details);
    } catch (_) {
      // notification failure shouldn't block anything else
    }
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

    // Use the last known position right away (don't wait for the first move):
    // lets nearby checks run immediately and tells the backend where we are.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _lastPosition = last;
      LocationSyncService.instance.maybeSend(last);
    }

    // Start picking up alerts the backend creates when a report is verified near us.
    AlertWatcher.instance.start();

    _started = true;
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    AlertWatcher.instance.stop();
    LocationSyncService.instance.stop();
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
    _lastPosition = pos;
    LocationSyncService.instance.maybeSend(pos); // keep the backend up to date
    _checkHazards(pos);
  }

  void _checkHazards(Position pos) {
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

    // 1. Local popup notification (sound + vibration)
    await notify(id: hazard.reportID, title: title, body: message);

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
