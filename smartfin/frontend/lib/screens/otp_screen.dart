import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dashboard_screen.dart';
import '../services/auth_service.dart';
import '../widgets/custom_snackbar.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  int? _attemptsLeft;
  int _resendCooldown = 0;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    HapticFeedback.mediumImpact();

    final code = _otpCode;
    
    if (code.length != 6) {
      _shake();
      CustomSnackbar.showError(context, 'Please enter all 6 digits');
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.verifyOtp(email: widget.email, code: code);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      CustomSnackbar.showSuccess(context, 'Verification successful!');
      HapticFeedback.heavyImpact();

      // Navigate to Dashboard with flip animation
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final angle = animation.value * 3.14159;
                return Transform(
                  transform: Matrix4.rotationY(angle),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
        (route) => false,
      );
    } else {
      _shake();
      
      if (result['attemptsLeft'] != null) {
        setState(() => _attemptsLeft = result['attemptsLeft']);
      }

      // Clear inputs on failure
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      CustomSnackbar.showError(context, result['message'] ?? 'Verification failed');
      HapticFeedback.vibrate();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final result = await AuthService.signupInit(email: widget.email, password: '');

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      CustomSnackbar.showSuccess(context, 'New code sent!');
      HapticFeedback.heavyImpact();

      // Clear inputs
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() {
        _attemptsLeft = null;
        _resendCooldown = 30;
      });

      // Start cooldown timer
      _startCooldownTimer();
    } else {
      CustomSnackbar.showError(context, result['message'] ?? 'Failed to resend');
      HapticFeedback.vibrate();
    }
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  void _shake() {
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-submit when last digit entered
    if (value.isNotEmpty && index == 5) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final offset = math.sin(_shakeController.value * math.pi * 4) * 10;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: _buildOtpCard(),
                ),
                const SizedBox(height: 32),
                _buildResendSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00488D).withAlpha(20),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.mark_email_unread,
            size: 40,
            color: Color(0xFF00488D),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Verify your email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00488D),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the 6-digit code sent to\n${widget.email}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // OTP Inputs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) => _buildOtpBox(index)),
          ),
          
          const SizedBox(height: 20),
          
          // Attempts warning
          if (_attemptsLeft != null && _attemptsLeft! < 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$_attemptsLeft attempts left',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00488D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF00488D).withAlpha(60),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Verify',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00488D),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF2F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00488D), width: 2),
          ),
        ),
        onChanged: (value) => _onChanged(value, index),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        TextButton(
          onPressed: _resendCooldown > 0 || _isLoading ? null : _resendOtp,
          child: Text(
            _resendCooldown > 0
                ? 'Resend code in $_resendCooldown s'
                : 'Resend code',
            style: TextStyle(
              color: _resendCooldown > 0 ? Colors.grey : const Color(0xFF00488D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: const Text(
            'Change email',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
