import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // ⚠️ IMPORTANT: Replace 192.168.1.X with your Computer's actual IP address.
  // Run 'ipconfig' in your computer terminal to find it.
  static const String baseUrl = "http://192.168.1.5:3000"; 
  
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json'
  };

  // STEP 1: Send Email & Password -> Request OTP
  // Returns a Map: { "success": true/false, "message": "..." }
  static Future<Map<String, dynamic>> signupInit({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup-init'), // Matches Node.js route
        headers: _headers,
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": "OTP sent successfully"};
      } else {
        return {"success": false, "message": data['message'] ?? "Failed to send OTP"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // STEP 2: Verify OTP -> Create Account
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-signup'), // Matches Node.js route
        headers: _headers,
        body: jsonEncode({"email": email, "code": code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Save 'data["token"]' to Shared Preferences here if you want auto-login
        return {"success": true, "message": "Account Verified! ✅"};
      } else {
        return {"success": false, "message": data['message'] ?? "Invalid Code"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection Error"};
    }
  }

  // LOGIN (Standard)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": "Login Successful"};
      } else {
        return {"success": false, "message": data['message'] ?? "Login Failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection Error"};
    }
  }
}