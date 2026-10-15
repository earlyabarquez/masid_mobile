import 'dart:async';
import 'alert_service.dart';
import 'proximity_service.dart';

/// Polls the backend for new "hazard" alerts (created when a report is verified
/// near this user) and shows a sound + vibration notification for each one.
/// Runs while the app is open.
class AlertWatcher {
  AlertWatcher._();
  static final AlertWatcher instance = AlertWatcher._();

  static const Duration _interval = Duration(seconds: 15);

  final _alertService = AlertService();
  Timer? _timer;
  bool _seeded = false;
  bool _busy = false;
  final Set<int> _seen = {};

  void start() {
    if (_timer != null) return;
    _poll();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final unread = await _alertService.getUnreadAlerts();

      // First poll: just remember what's already there so opening the app
      // doesn't fire a notification for every old unread alert.
      if (!_seeded) {
        _seen.addAll(unread.map((a) => a.alertID));
        _seeded = true;
        return;
      }

      for (final a in unread) {
        if (!_seen.add(a.alertID)) continue; // already handled
        if (a.type != 'hazard') continue;

        // The on-device proximity check may already have warned about this hazard.
        if (ProximityService.instance.hasAlerted(a.hazardID)) continue;
        ProximityService.instance.markAlerted(a.hazardID);

        await ProximityService.instance.notify(
          id: a.hazardID,
          title: a.title,
          body: a.message,
        );
      }
    } catch (_) {
      // Network hiccup — try again on the next tick.
    } finally {
      _busy = false;
    }
  }
}
