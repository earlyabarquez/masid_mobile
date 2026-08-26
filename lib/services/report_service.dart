import 'dart:convert';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

class ReportService {
  final _dio = DioClient.instance;

  Future<void> submitReport({
    required int hazardID,
    required int severity,
    required String description,
    required double latitude,
    required double longitude,
    required String imageURL,
  }) async {
    // Get the logged-in user's ID from stored user data
    final userJson = await TokenStorage.getUser();
    if (userJson == null) {
      throw Exception('Not logged in');
    }
    final user = jsonDecode(userJson);
    final userID = user['userID']; // <-- must match your login response field
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
}
