import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'http://127.0.0.1:8000/api'; // sesuaikan server

  Future<Map<String, dynamic>> loginStudent(
      String email, String nisn, String password) async {
    final url = Uri.parse('$baseUrl/login-student');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email,
        'nisn': nisn,
        'password': password,
      }),
    );

    return _handleLoginResponse(response);
  }

  Future<Map<String, dynamic>> _handleLoginResponse(http.Response response) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonDecode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final accessToken = jsonData['access_token'] ?? '';
      final refreshToken = jsonData['refresh_token'] ?? '';
      final userData = jsonData['data'] ?? {};

      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('user_name', userData['name'] ?? '');
      await prefs.setString('user_role', userData['role'] ?? '');

      return {
        'success': true,
        'message': jsonData['message'],
        'data': userData,
      };
    } else {
      return {
        'success': false,
        'message': jsonData['message'] ?? 'Login gagal',
      };
    }
  }
}
