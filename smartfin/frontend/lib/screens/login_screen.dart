import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;

  // Tracks whether we've already shown the "cannot reach server" hint so we
  // don't spam the user with the same diagnostic message on every retry.
  bool _shownConnectivityHint = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email and password are required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth    = context.read<AuthProvider>();
    final success = await auth.login(email: email, password: password);
    if (!mounted) return;

    if (success) {
      _shownConnectivityHint = false;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // ── Error handling ─────────────────────────────────────────────────────
    final msg       = auth.errorMessage ?? 'Login failed. Please try again.';
    final isTimeout = auth.isTimeout;

    // Detect "cannot reach server" errors (SocketException path).
    final isUnreachable = msg.contains('Cannot reach') ||
        msg.contains('No internet') ||
        msg.contains('Network error');

    // Show a connectivity hint once — tells the user exactly what to check.
    if (isUnreachable && !_shownConnectivityHint) {
      _shownConnectivityHint = true;
      _showConnectivityDialog();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isTimeout
            ? Colors.orange.shade700
            : Colors.red.shade700,
        duration: const Duration(seconds: 6),
        action: (isTimeout || isUnreachable)
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _shownConnectivityHint = false;
                  _onLogin();
                },
              )
            : null,
      ),
    );
  }

  /// Shows a dialog with actionable steps when the backend is unreachable.
  void _showConnectivityDialog() {
    final platform = Platform.isAndroid ? 'Android emulator' : 'iOS simulator / device';
    final expectedUrl = ApiClient.baseUrl;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot reach server'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The app is trying to connect to:\n$expectedUrl'),
              const SizedBox(height: 12),
              const Text('Checklist:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('1. Backend is running  (node index.js)'),
              const Text('2. Backend listens on  0.0.0.0:3000'),
              Text('3. You are on a $platform'),
              if (Platform.isAndroid)
                const Text('   → Android emulator uses 10.0.2.2 for host'),
              if (!Platform.isAndroid)
                const Text('   → iOS simulator uses 127.0.0.1 for host'),
              const Text('4. No firewall blocking port 3000'),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                const Text(
                  'To use a physical device, build with:\n'
                  '--dart-define=SMARTFIN_API_URL=http://<your-LAN-IP>:3000',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shownConnectivityHint = false;
              _onLogin();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // B3 fix: use context.read for static content that never changes at runtime.
    // This prevents the entire login screen from rebuilding every time
    // FinanceProvider notifies (which happens 6+ times during loadAll()).
    final content   = context.read<FinanceProvider>().loginContent;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                ),

                const SizedBox(height: 16),

                const Text(
                  "SmartFin",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A3D62),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  content.tagline,
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Email Address"),
                      const SizedBox(height: 8),
                      _inputField(
                        hint: content.emailHint,
                        icon: Icons.email_outlined,
                        controller: _emailCtrl,
                        suffix: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Password"),
                          Text(
                            "Forgot Password?",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Fix #11: password field now uses _passwordVisible state.
                      _inputField(
                        hint: "••••••••",
                        icon: Icons.lock_outline,
                        controller: _passwordCtrl,
                        obscure: !_passwordVisible,
                        suffix: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isLoading ? null : _onLogin,
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In →',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("OR CONTINUE WITH"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: _socialButton(icon: Icons.g_mobiledata, text: "Google")),
                          const SizedBox(width: 12),
                          Expanded(child: _socialButton(icon: Icons.apple, text: "Apple")),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? "),
                    _SignUpLink(),
                  ],
                ),

                const SizedBox(height: 16),

                const Text(
                  "AES-256 ENCRYPTED CONNECTION",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fix #11: changed from static to instance method so suffix widgets
  // (e.g. IconButton with setState) work correctly.
  Widget _inputField({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool obscure = false,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF1F3F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static Widget _socialButton({required IconData icon, required String text}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(width: 6), Text(text)],
      ),
    );
  }
}

/// Tappable "Sign Up" link — needs BuildContext so it's a separate widget.
class _SignUpLink extends StatelessWidget {
  const _SignUpLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SmartFinSignUp()),
      ),
      child: const Text(
        'Sign Up',
        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
      ),
    );
  }
}
