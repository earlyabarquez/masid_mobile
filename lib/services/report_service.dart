import 'dart:convert';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

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
}

class ReportService {
  final _dio = DioClient.instance;

  // ── Submit a new report ──
  Future<void> submitReport({
    required int hazardID,
    required int severity,
    required String description,
    required double latitude,
    required double longitude,
    required String imageURL,
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
      },
    );
  }

  // ── Fetch ALL reports (for the map — filter to verified in the caller) ──
  Future<List<Report>> getAllReports() async {
    final res = await _dio.get('/api/hazards');
    return (res.data as List).map((j) => Report.fromJson(j)).toList();
  }

  // ── Fetch only VERIFIED reports (for the map) ──
  Future<List<Report>> getVerifiedReports() async {
    final all = await getAllReports();
    return all.where((r) => r.statusName == 'Verified').toList();
  }

  // ── Fetch the logged-in user's own reports (for the Reports tab) ──
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

    final res = await _dio.get(
      '/api/hazards/my-reports',
      queryParameters: {'userID': userID},
    );
    return (res.data as List).map((j) => Report.fromJson(j)).toList();
  }
}
