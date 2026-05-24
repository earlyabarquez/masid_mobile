import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class TokenStorage {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> saveUser(String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, userJson);
  }

  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
