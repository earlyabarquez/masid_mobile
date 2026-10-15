import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

/// Tells the backend where this user is, so it can alert them when a report is
/// verified near them. Sends the first fix, then again after the user has moved
/// ~50 m, plus a 5-minute heartbeat so a stationary user still counts as "recent".
class LocationSyncService {
  LocationSyncService._();
  static final LocationSyncService instance = LocationSyncService._();

  static const Duration _minGap = Duration(seconds: 15);
  static const Duration _heartbeat = Duration(minutes: 5);
  static const double _minMoveMeters = 50;

  final _dio = DioClient.instance;

  Timer? _heartbeatTimer;
  Position? _lastPos; // latest position we know about
  Position? _sentPos; // last position the server has
  DateTime? _sentAt;
  bool _sending = false;

  /// Call with every new position. Decides by itself whether to upload.
  void maybeSend(Position pos) {
    _lastPos = pos;
    _heartbeatTimer ??= Timer.periodic(_heartbeat, (_) => _resend());

    final sentPos = _sentPos;
    final sentAt = _sentAt;
    if (sentPos == null || sentAt == null) {
      _send(pos); // first fix
      return;
    }

    final gap = DateTime.now().difference(sentAt);
    final moved = Geolocator.distanceBetween(
      sentPos.latitude,
      sentPos.longitude,
      pos.latitude,
      pos.longitude,
    );
    if (moved >= _minMoveMeters && gap >= _minGap) _send(pos);
  }

  void _resend() {
    final pos = _lastPos;
    if (pos != null) _send(pos);
  }

  Future<void> _send(Position pos) async {
    if (_sending) return;
    _sending = true;
    try {
      final userJson = await TokenStorage.getUser();
      if (userJson == null) return;
      final userID = jsonDecode(userJson)['userID'] as int?;
      if (userID == null) return;

      await _dio.put(
        '/api/user-locations',
        queryParameters: {
          'userID': userID,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        },
      );
      _sentPos = pos;
      _sentAt = DateTime.now();
    } catch (_) {
      // Non-fatal: we'll try again on the next position / heartbeat.
    } finally {
      _sending = false;
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
