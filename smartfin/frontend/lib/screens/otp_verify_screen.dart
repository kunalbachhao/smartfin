// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_services.dart';
import 'dashboard_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false; // 1. Added loading state

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      _showMessage("Please enter the OTP");
      return;
    }

    // 2. Start Loading
    setState(() => _isLoading = true);

    // 3. Call API (Returns a Map, not a bool)
    final result = await ApiService.verifyOtp(widget.email, code);

    // 4. Stop Loading
    if (mounted) {
      setState(() => _isLoading = false);
    }

    // 5. Check Success
    if (result['success']) {
      // Optional: You can save the token here using SharedPreferences
      // String token = result['token']; 
      
      _showMessage("Verification Successful!");
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // Show specific error from backend (e.g., "Invalid OTP")
      _showMessage(result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OTP Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter the 6-digit code sent to:",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 5),
            Text(
              widget.email,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6, // Limit to 6 digits
              enabled: !_isLoading,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "000000",
                counterText: "", // Hides the character counter below
              ),
            ),
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}