import 'dart:convert';
import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../utils/token_storage.dart';

class AuthResult {
  final bool success;
  final String? error;
  AuthResult({required this.success, this.error});
}

class AuthService {
  final Dio _dio = DioClient.instance;

  // LOGIN
  Future<AuthResult> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      final data =
          res.data; // { token, userID, email, firstName, lastName, role }
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        return AuthResult(success: false, error: 'No token returned');
      }

      await TokenStorage.saveToken(token);
      await TokenStorage.saveUser(jsonEncode(data));

      return AuthResult(success: true);
    } on DioException catch (e) {
      // Backend returns { "error": "..." } on 400
      final msg = e.response?.data is Map
          ? (e.response?.data['error'] ?? 'Login failed')
          : 'Cannot connect to server';
      return AuthResult(success: false, error: msg.toString());
    } catch (e) {
      return AuthResult(success: false, error: 'Something went wrong');
    }
  }

  // REGISTER (responder)
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? position,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'position': position ?? 'Responder',
          'roleID': 2, // 2 = Responder
        },
      );

      final data = res.data;
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUser(jsonEncode(data));
      }
      return AuthResult(success: true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error'] ?? 'Registration failed')
          : 'Cannot connect to server';
      return AuthResult(success: false, error: msg.toString());
    } catch (e) {
      return AuthResult(success: false, error: 'Something went wrong');
    }
  }
}
