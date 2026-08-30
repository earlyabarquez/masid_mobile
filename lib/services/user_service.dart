import 'dart:convert';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

class UserService {
  final _dio = DioClient.instance;

  Future<int?> _currentUserID() async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) return null;
    final user = jsonDecode(userJson);
    return user['userID'] as int?;
  }

  // Update the logged-in user's profile. Sends the full middle name
  // (backend stores the full name and displays it as an initial).
  // Returns the updated user map (also refreshes local storage).
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
    required String email,
  }) async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) throw Exception('Not logged in');
    final current = jsonDecode(userJson) as Map<String, dynamic>;
    final userID = current['userID'];
    if (userID == null) throw Exception('No user ID');

    // Start from the current user so we don't drop fields the backend needs
    final payload = Map<String, dynamic>.from(current);
    payload['firstName'] = firstName;
    payload['middleInitial'] =
        middleName; // backend stores full middle name here
    payload['lastName'] = lastName;
    payload['phone'] = phone;
    payload['email'] = email;
    // Never send a password on a profile edit (would overwrite it)
    payload.remove('password');

    final res = await _dio.put('/api/users/updateUser/$userID', data: payload);

    // Merge the response (or our payload) back into local storage
    final updated = (res.data is Map)
        ? Map<String, dynamic>.from(res.data)
        : payload;
    // Keep fields the response might omit (e.g. role/token-related)
    final merged = Map<String, dynamic>.from(current)..addAll(updated);
    merged.remove('password');
    await TokenStorage.saveUser(jsonEncode(merged));

    return merged;
  }

  // Change the logged-in user's password (verifies the current password).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final userID = await _currentUserID();
    if (userID == null) throw Exception('Not logged in');

    await _dio.put(
      '/api/users/$userID/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
