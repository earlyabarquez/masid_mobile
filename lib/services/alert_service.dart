import 'dart:convert';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

// ── Alert model (matches the backend Alerts entity) ──
class AppAlert {
  final int alertID;
  final int userID;
  final int hazardID;
  final String type; // "statusUpdate" or "hazard"
  final String title;
  final String message;
  bool isRead;
  final String? createdAt;

  AppAlert({
    required this.alertID,
    required this.userID,
    required this.hazardID,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppAlert.fromJson(Map<String, dynamic> json) {
    return AppAlert(
      alertID: json['alertID'] ?? 0,
      userID: json['userID'] ?? 0,
      hazardID: json['hazardID'] ?? 0,
      type: json['type'] ?? 'statusUpdate',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class AlertService {
  final _dio = DioClient.instance;

  Future<int?> _currentUserID() async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) return null;
    final user = jsonDecode(userJson);
    return user['userID'] as int?;
  }

  // Count unread alerts for the logged-in user (for the nav badge)
  Future<int> unreadCount() async {
    final userID = await _currentUserID();
    if (userID == null) return 0;
    final res = await _dio.get(
      '/api/alerts/unread',
      queryParameters: {'userID': userID},
    );
    return (res.data as List).length;
  }

  // Fetch all alerts for the logged-in user
  Future<List<AppAlert>> getMyAlerts() async {
    final userID = await _currentUserID();
    if (userID == null) throw Exception('Not logged in');

    final res = await _dio.get(
      '/api/alerts',
      queryParameters: {'userID': userID},
    );
    return (res.data as List).map((j) => AppAlert.fromJson(j)).toList();
  }

  // Mark one alert as read
  Future<void> markAsRead(int alertID) async {
    await _dio.put('/api/alerts/$alertID/read');
  }

  // Mark all of the user's alerts as read
  Future<void> markAllAsRead() async {
    final userID = await _currentUserID();
    if (userID == null) throw Exception('Not logged in');
    await _dio.put('/api/alerts/read-all', queryParameters: {'userID': userID});
  }

  // Create a hazard proximity alert (deduplicated on the backend — won't
  // create a duplicate if an unread hazard alert for this hazard already exists)
  Future<void> createHazardAlert({
    required int hazardID,
    required String title,
    required String message,
  }) async {
    final userID = await _currentUserID();
    if (userID == null) throw Exception('Not logged in');

    await _dio.post(
      '/api/alerts/hazard',
      data: {
        'userID': userID,
        'hazardID': hazardID,
        'type': 'hazard',
        'title': title,
        'message': message,
        'isRead': false,
      },
    );
  }
}
