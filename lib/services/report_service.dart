import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';
import 'local_db.dart';

// ── Report model (matches the backend ReportResponse) ──
class Report {
  final int reportID;
  final String hazardName;
  final String statusName;
  final String? barangayName;
  final String? reporterName;
  final int severity;
  final double? weight;
  final String description;
  final String? imageURL;
  final double latitude;
  final double longitude;
  final String? address;
  final String? adminNotes;
  final String? reportDate;
  final String? verifiedBy;
  final String? verifiedAt;

  Report({
    required this.reportID,
    required this.hazardName,
    required this.statusName,
    this.barangayName,
    this.reporterName,
    required this.severity,
    this.weight,
    required this.description,
    this.imageURL,
    required this.latitude,
    required this.longitude,
    this.address,
    this.adminNotes,
    this.reportDate,
    this.verifiedBy,
    this.verifiedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportID: json['reportID'],
      hazardName: json['hazardName'] ?? 'Unknown',
      statusName: json['statusName'] ?? 'Pending',
      barangayName: json['barangayName'],
      reporterName: json['reporterName'],
      severity: json['severity'] ?? 1,
      weight: (json['weight'] as num?)?.toDouble(),
      description: json['description'] ?? '',
      imageURL: json['imageURL'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'],
      adminNotes: json['adminNotes'],
      reportDate: json['reportDate']?.toString(),
      verifiedBy: json['verifiedBy'],
      verifiedAt: json['verifiedAt']?.toString(),
    );
  }

  // Same keys as fromJson — used to save a copy on the phone for offline use.
  Map<String, dynamic> toJson() => {
    'reportID': reportID,
    'hazardName': hazardName,
    'statusName': statusName,
    'barangayName': barangayName,
    'reporterName': reporterName,
    'severity': severity,
    'weight': weight,
    'description': description,
    'imageURL': imageURL,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'adminNotes': adminNotes,
    'reportDate': reportDate,
    'verifiedBy': verifiedBy,
    'verifiedAt': verifiedAt,
  };
}

class ReportService {
  final _dio = DioClient.instance;

  /// True when the last getVerifiedReports() / getMyReports() call returned the
  /// copy saved on the phone (no connection) instead of fresh data.
  bool lastLoadFromCache = false;

  // ── Submit a new report ──
  // [reportDate] (ISO-8601, local time) lets a report that was saved offline keep
  // the time it was actually made; leave it null to let the server stamp "now".
  Future<void> submitReport({
    required int hazardID,
    required int severity,
    required String description,
    required double latitude,
    required double longitude,
    required String imageURL,
    String? reportDate,
  }) async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) {
      throw Exception('Not logged in');
    }
    final user = jsonDecode(userJson);
    final userID = user['userID'];
    if (userID == null) {
      throw Exception('No user ID found');
    }

    await _dio.post(
      '/api/hazards',
      data: {
        'userID': userID,
        'hazardID': hazardID,
        'statusID': 1, // Pending
        'severity': severity,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'imageURL': imageURL,
        if (reportDate != null) 'reportDate': reportDate,
      },
    );
  }

  // ── Fetch ALL reports (for the map — filter to verified in the caller) ──
  Future<List<Report>> getAllReports() async {
    final res = await _dio.get('/api/hazards');
    return (res.data as List).map((j) => Report.fromJson(j)).toList();
  }

  // ── Fetch only VERIFIED reports (for the map) ──
  // Online: fresh list (and a copy is saved). Offline: the saved copy.
  Future<List<Report>> getVerifiedReports() async {
    try {
      final all = await getAllReports();
      final verified = all.where((r) => r.statusName == 'Verified').toList();
      lastLoadFromCache = false;
      await _saveToCache('verified', verified);
      return verified;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403)
        rethrow; // a login problem, not a connection one
      final cached = await _loadFromCache('verified');
      if (cached != null) {
        lastLoadFromCache = true;
        return cached;
      }
      rethrow;
    }
  }

  // ── Fetch the logged-in user's own reports (for the Reports tab) ──
  // Online: fresh list (and a copy is saved). Offline: the saved copy.
  Future<List<Report>> getMyReports() async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) {
      throw Exception('Not logged in');
    }
    final user = jsonDecode(userJson);
    final userID = user['userID'];
    if (userID == null) {
      throw Exception('No user ID found');
    }

    final key = 'mine:$userID';
    try {
      final res = await _dio.get(
        '/api/hazards/my-reports',
        queryParameters: {'userID': userID},
      );
      final list = (res.data as List).map((j) => Report.fromJson(j)).toList();
      lastLoadFromCache = false;
      await _saveToCache(key, list);
      return list;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) rethrow;
      final cached = await _loadFromCache(key);
      if (cached != null) {
        lastLoadFromCache = true;
        return cached;
      }
      rethrow;
    }
  }

  // ── Saved copy (offline) ──
  Future<void> _saveToCache(String key, List<Report> list) async {
    try {
      final db = await LocalDb.instance.database;
      await db.transaction((txn) async {
        await txn.delete(
          'cached_reports',
          where: 'list_key = ?',
          whereArgs: [key],
        );
        final batch = txn.batch();
        // marker row: "this list has been saved" (even when it is empty)
        batch.insert('cached_reports', {
          'list_key': key,
          'report_id': -1,
          'json': '',
        });
        for (final r in list) {
          batch.insert('cached_reports', {
            'list_key': key,
            'report_id': r.reportID,
            'json': jsonEncode(r.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } catch (_) {
      // caching is best-effort
    }
  }

  // Returns null if this list was never saved.
  Future<List<Report>?> _loadFromCache(String key) async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query(
        'cached_reports',
        where: 'list_key = ?',
        whereArgs: [key],
      );
      if (rows.isEmpty) return null;
      return rows
          .where((r) => (r['report_id'] as num).toInt() >= 0)
          .map(
            (r) => Report.fromJson(
              jsonDecode(r['json'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }
}
