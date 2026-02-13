// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/api_services.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart'; // Make sure you import your Home/Dashboard screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Added loading state

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("All fields are required");
      return;
    }

    // Start Loading
    setState(() => _isLoading = true);

    // CALL THE LOGIN API (Not Signup)
    final result = await ApiService.login(email, password);

    // Stop Loading
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (result['success']) {
      // Login Success -> Go to Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // Login Failed -> Show Error
      _showMessage(result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTextField(_emailController, "Email", false),
            const SizedBox(height: 20),
            _buildTextField(_passwordController, "Password", true),
            const SizedBox(height: 30),
            
            // Login Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Login"),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Link to Signup
            GestureDetector(
              onTap: _isLoading 
                  ? null 
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
              child: Text(
                "Don't have an account? Sign Up",
                style: TextStyle(
                  color: _isLoading ? Colors.grey : Colors.blue, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    bool isPassword,
  ) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      obscureText: isPassword && !_isPasswordVisible,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              )
            : null,
      ),
    );
  }
}