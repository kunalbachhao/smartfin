import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://equation-anthem-delay.ngrok-free.dev';

  // Generic POST request handler
  static Future<Map<String, dynamic>> _postRequest(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // Check if response is HTML (server crash / ngrok issue)
      if (response.headers['content-type']?.contains('text/html') ?? false) {
        return {
          'success': false,
          'message': 'Server error: Received HTML instead of JSON'
        };
      }

      // Safe JSON parsing
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'statusCode': response.statusCode,
        'data': data
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // Signup Step 1
  static Future<Map<String, dynamic>> signupInit(
      String email, String password) async {
    final res = await _postRequest('signup-init', {
      'email': email,
      'password': password,
    });

    return res['success']
        ? {'success': true, 'message': res['data']['message']}
        : {
            'success': false,
            'message': res['data']?['message'] ?? 'Signup failed'
          };
  }

  // Signup Step 2 (OTP)
  static Future<Map<String, dynamic>> verifyOtp(
      String email, String code) async {
    final res = await _postRequest('verify-signup', {
      'email': email,
      'code': code,
    });

    return res['statusCode'] == 201
        ? {'success': true, 'token': res['data']['token']}
        : {
            'success': false,
            'message': res['data']?['message'] ?? 'Verification failed'
          };
  }

  // Login
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
      final res = await _postRequest('login', {
      'email': email,
      'password': password,
    });

    return res['success']
        ? {
            'success': true,
            'token': res['data']['token'],
            'message': 'Login Successful'
          }
        : {
            'success': false,
            'message': res['data']?['message'] ?? 'Login Failed'
          };
  }
}