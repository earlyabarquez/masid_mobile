import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'cloudinary_service.dart';
import 'hazard_service.dart';
import 'local_db.dart';
import 'report_service.dart';

/// A hazard type as the report form needs it (id + name). Saved on the phone so
/// the form still works without internet.
class HazardOption {
  final int hazardID;
  final String hazardName;
  const HazardOption(this.hazardID, this.hazardName);
}

/// A report saved on the phone that hasn't reached the server yet.
class PendingReport {
  final int id;
  final String hazardName;
  final int severity;
  final String description;
  final double latitude;
  final double longitude;
  final String createdAt; // ISO-8601 local time (when the report was made)
  final bool failed; // the server rejected it several times — needs attention

  const PendingReport({
    required this.id,
    required this.hazardName,
    required this.severity,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.failed,
  });
}

/// True when [e] looks like a connection problem (no internet, timeout, DNS…)
/// as opposed to the server rejecting the request.
bool isNetworkError(Object e) {
  if (e is SocketException || e is TimeoutException) return true;
  if (e is DioException) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.error is SocketException;
  }
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused') ||
      s.contains('Connection closed') ||
      s.contains('timed out');
}

bool _isAuthError(Object e) =>
    e is DioException &&
    (e.response?.statusCode == 401 || e.response?.statusCode == 403);

/// Saves reports made without internet on the phone and sends them
/// automatically once the connection is back. Also keeps a saved copy of the
/// hazard types for the report form.
class OfflineReportService {
  OfflineReportService._();
  static final OfflineReportService instance = OfflineReportService._();

  // After this many server rejections a report stops being retried automatically
  // (it stays on the phone and shows as "Not sent" in My Reports).
  static const int _maxAttempts = 5;

  final _reportService = ReportService();

  /// Reports still being retried automatically (for UI badges).
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Reports the server keeps rejecting (need the user's attention).
  final ValueNotifier<int> failedCount = ValueNotifier<int>(0);

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _retryTimer;
  bool _syncing = false;

  // ── Connectivity ──
  Future<bool> isOffline() async {
    final r = await Connectivity().checkConnectivity();
    return r.isEmpty || r.every((x) => x == ConnectivityResult.none);
  }

  /// Start watching the connection and sending saved reports. Safe to call twice.
  void start() {
    if (_connSub != null) return;
    refreshCount();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty || results.every((x) => x == ConnectivityResult.none);
      if (!offline) {
        syncPending();
        prefetchHazardTypes();
      }
    });
    // Also retry every couple of minutes (covers "connected to Wi-Fi but no internet").
    _retryTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => syncPending(),
    );
    syncPending(); // anything left over from last time
    prefetchHazardTypes();
  }

  void stop() {
    _connSub?.cancel();
    _connSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ── Hazard types (saved copy for the report form) ──
  Future<void> saveHazardTypes(List<HazardOption> list) async {
    try {
      final db = await LocalDb.instance.database;
      await db.transaction((txn) async {
        await txn.delete('hazard_types');
        final batch = txn.batch();
        for (final h in list) {
          batch.insert('hazard_types', {
            'hazard_id': h.hazardID,
            'hazard_name': h.hazardName,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } catch (_) {}
  }

  Future<List<HazardOption>> loadHazardTypes() async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query('hazard_types', orderBy: 'hazard_id ASC');
      return rows
          .map(
            (r) => HazardOption(
              (r['hazard_id'] as num).toInt(),
              (r['hazard_name'] as String?) ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Refresh the saved hazard types while online (so the form works offline later).
  Future<void> prefetchHazardTypes() async {
    try {
      final hazards = await HazardService().getHazardTypes();
      await saveHazardTypes(
        hazards.map((h) => HazardOption(h.hazardID, h.hazardName)).toList(),
      );
    } catch (_) {}
  }

  // ── Pending reports ──
  Future<void> refreshCount() async {
    try {
      final db = await LocalDb.instance.database;
      final waiting = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM pending_reports WHERE attempts < ?',
          [_maxAttempts],
        ),
      );
      final failed = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM pending_reports WHERE attempts >= ?',
          [_maxAttempts],
        ),
      );
      pendingCount.value = waiting ?? 0;
      failedCount.value = failed ?? 0;
    } catch (_) {}
  }

  /// Everything saved on the phone and not yet sent (newest first).
  Future<List<PendingReport>> loadPending() async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.rawQuery('''
        SELECT p.id, p.severity, p.description, p.latitude, p.longitude,
               p.created_at, p.attempts, h.hazard_name AS hazard_name
        FROM pending_reports p
        LEFT JOIN hazard_types h ON h.hazard_id = p.hazard_id
        ORDER BY p.id DESC
      ''');
      return rows
          .map(
            (r) => PendingReport(
              id: (r['id'] as num).toInt(),
              hazardName: (r['hazard_name'] as String?) ?? 'Hazard report',
              severity: (r['severity'] as num).toInt(),
              description: (r['description'] as String?) ?? '',
              latitude: (r['latitude'] as num).toDouble(),
              longitude: (r['longitude'] as num).toDouble(),
              createdAt: (r['created_at'] as String?) ?? '',
              failed: ((r['attempts'] as num?)?.toInt() ?? 0) >= _maxAttempts,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a report on the phone to be sent later.
  /// If the photo was already uploaded, pass [imageUrl] and it won't be re-uploaded.
  Future<void> enqueue({
    required XFile photo,
    required int hazardID,
    required int severity,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
  }) async {
    String? photoPath;
    if (imageUrl == null || imageUrl.isEmpty) {
      // Keep our own copy of the photo (the camera's temp file can be cleaned up).
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'pending_reports'));
      if (!await folder.exists()) await folder.create(recursive: true);
      photoPath = p.join(
        folder.path,
        'report_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(photo.path).copy(photoPath);
    }

    final db = await LocalDb.instance.database;
    await db.insert('pending_reports', {
      'hazard_id': hazardID,
      'severity': severity,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'photo_path': photoPath,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
    await refreshCount();
  }

  /// Delete a saved report (and its photo) without sending it.
  Future<void> discard(int id) async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query(
        'pending_reports',
        columns: ['photo_path'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty)
        await _deletePhoto(rows.first['photo_path'] as String?);
      await db.delete('pending_reports', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
    await refreshCount();
  }

  Future<void> _deletePhoto(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Send every waiting report. Returns how many were sent.
  /// Stops early if the connection is down or the login has expired
  /// (the reports stay saved and are retried later).
  /// [retryFailed] also gives the "Not sent" ones another go.
  Future<int> syncPending({bool retryFailed = false}) async {
    if (_syncing) return 0;
    _syncing = true;
    var sent = 0;
    try {
      final db = await LocalDb.instance.database;
      if (retryFailed) {
        await db.rawUpdate(
          'UPDATE pending_reports SET attempts = 0 WHERE attempts >= ?',
          [_maxAttempts],
        );
      }
      final rows = await db.query(
        'pending_reports',
        where: 'attempts < ?',
        whereArgs: [_maxAttempts],
        orderBy: 'id ASC',
      );

      for (final row in rows) {
        final id = row['id'] as int;
        try {
          final hazardID = (row['hazard_id'] as num).toInt();
          final severity = (row['severity'] as num).toInt();
          final description = (row['description'] as String?) ?? '';
          final latitude = (row['latitude'] as num).toDouble();
          final longitude = (row['longitude'] as num).toDouble();
          final cachedUrl = row['image_url'] as String?;
          // Keep the time the report was actually made (not the time it synced).
          final madeAt = row['created_at'] as String?;

          if (cachedUrl != null && cachedUrl.isNotEmpty) {
            await _reportService.submitReport(
              hazardID: hazardID,
              severity: severity,
              description: description,
              latitude: latitude,
              longitude: longitude,
              imageURL: cachedUrl,
              reportDate: madeAt,
            );
          } else {
            // 1. Upload the saved photo
            final uploaded = await CloudinaryService.uploadImage(
              XFile(row['photo_path'] as String),
            );
            // remember the URL so a retry doesn't upload the photo again
            await db.update(
              'pending_reports',
              {'image_url': uploaded},
              where: 'id = ?',
              whereArgs: [id],
            );
            // 2. Submit the report
            await _reportService.submitReport(
              hazardID: hazardID,
              severity: severity,
              description: description,
              latitude: latitude,
              longitude: longitude,
              imageURL: uploaded,
              reportDate: madeAt,
            );
          }

          // Sent — remove it and its saved photo.
          await _deletePhoto(row['photo_path'] as String?);
          await db.delete('pending_reports', where: 'id = ?', whereArgs: [id]);
          sent++;
        } catch (e) {
          await db.rawUpdate(
            'UPDATE pending_reports SET attempts = attempts + ?, last_error = ? WHERE id = ?',
            [isNetworkError(e) ? 0 : 1, e.toString(), id],
          );
          // No connection / expired login: stop and try again later.
          if (isNetworkError(e) || _isAuthError(e)) break;
          // Otherwise the server rejected this one — move on to the next.
        }
      }
    } finally {
      _syncing = false;
      await refreshCount();
    }
    return sent;
  }
}
