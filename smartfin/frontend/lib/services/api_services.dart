import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ FIX: Changed to 127.0.0.1 because you ran 'adb reverse tcp:3000 tcp:3000'
  // The phone now treats the computer as its own localhost.
  static const String baseUrl = 'http://127.0.0.1:3000';

  // Step 1: Send Email & Password -> Backend hashes pass & sends OTP
  static Future<Map<String, dynamic>> signupInit(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup-init'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password 
        }),
      );

      // Handle cases where the server returns HTML instead of JSON (server error)
      if (response.headers['content-type']?.contains('text/html') ?? false) {
         return {'success': false, 'message': 'Server error: Received HTML instead of JSON'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Signup failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // Step 2: Verify OTP -> Backend creates user in MongoDB
  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'token': data['token']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Verification failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // Login Method
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'token': data['token'], 'message': 'Login Successful'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }
}