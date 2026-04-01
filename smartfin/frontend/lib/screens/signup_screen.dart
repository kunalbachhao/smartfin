// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_services.dart';
import 'login_screen.dart';
import 'otp_verify_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmHasFocus = false;

  // ── Brand Colors ──
  static const Color _primaryColor = Color(0xFF00796B);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _accentColor = Color(0xFF26A69A);
  static const Color _surfaceColor = Color(0xFFF5FFFE);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF888888);
  static const Color _inputBorder = Color(0xFFE8E8E8);
  static const Color _errorColor = Color(0xFFE53935);

  late AnimationController _backgroundAnimController;
  late AnimationController _fadeSlideController;
  late AnimationController _headerController;
  late AnimationController _buttonController;

  late Animation<double> _headerScale;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();

    _backgroundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerScale = CurvedAnimation(
      parent: _headerController,
      curve: Curves.elasticOut,
    );

    _fadeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeSlideController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeSlideController,
      curve: Curves.easeOutCubic,
    ));

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeSlideController.forward();
    });

    _emailFocus.addListener(() => setState(() => _emailHasFocus = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordHasFocus = _passwordFocus.hasFocus));
    _confirmFocus.addListener(() => setState(() => _confirmHasFocus = _confirmFocus.hasFocus));
  }

  @override
  void dispose() {
    _backgroundAnimController.dispose();
    _fadeSlideController.dispose();
    _headerController.dispose();
    _buttonController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _errorColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Route _createFlipRoute(Widget targetPage, {bool leftToRight = false}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => targetPage,
      transitionDuration: const Duration(milliseconds: 700),
      reverseTransitionDuration: const Duration(milliseconds: 700),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final curve = Curves.easeInOutCubic.transform(animation.value);
            final direction = leftToRight ? -1 : 1;
            final angle = direction * (1 - curve) * (math.pi / 2);

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(-angle),
              child: Opacity(
                opacity: curve.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      HapticFeedback.heavyImpact();
      _showMessage("All fields are required");
      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      HapticFeedback.heavyImpact();
      _showMessage("Please enter a valid email address");
      return;
    }

    if (password != confirmPassword) {
      HapticFeedback.heavyImpact();
      _showMessage("Passwords do not match");
      return;
    }

    if (password.length < 6) {
      HapticFeedback.heavyImpact();
      _showMessage("Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await ApiService.signupInit(email, password);

    if (mounted) setState(() => _isLoading = false);

    if (result['success']) {
      HapticFeedback.mediumImpact();
      _showMessage(result['message'], isError: false);

      Navigator.push(
        context,
        _createFlipRoute(OtpVerificationScreen(email: email)),
      );
    } else {
      HapticFeedback.heavyImpact();
      _showMessage(result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildFloatingShapes(),

            SafeArea(
              child: Column(
                children: [
                  // ── TOP APP BAR (Icon + Exit) ──
                  _buildTopBar(),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: Column(
                        children: [
                          const SizedBox(height: 5),

                          // ── TITLE & SUBTITLE ──
                          _buildHeader(),

                          const SizedBox(height: 25),

                          // ── FORM CARD ──
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildFormCard(),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── LOGIN LINK ──
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildLoginLink(),
                          ),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //           TOP BAR
  // ══════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded, // Slightly different icon for signup
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "SMARTFIN",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 26, color: _textGrey),
            tooltip: "Exit App",
            onPressed: () {
              HapticFeedback.mediumImpact();
              SystemNavigator.pop();
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //           BACKGROUND & SHAPES
  // ══════════════════════════════════════════

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _surfaceColor,
            Colors.white,
            Color(0xFFF0FAF8),
            Colors.white,
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildFloatingShapes() {
    return AnimatedBuilder(
      animation: _backgroundAnimController,
      builder: (context, child) {
        final value = _backgroundAnimController.value;
        return Stack(
          children: [
            Positioned(
              top: -60 + math.sin(value * 2 * math.pi) * 15,
              left: -40 + math.cos(value * 2 * math.pi) * 10,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.06),
                      _primaryColor.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80 + math.cos(value * 2 * math.pi) * 20,
              right: -60 + math.sin(value * 2 * math.pi) * 12,
              child: Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentColor.withValues(alpha: 0.05),
                      _accentColor.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //           HEADER
  // ══════════════════════════════════════════

  Widget _buildHeader() {
    return ScaleTransition(
      scale: _headerScale,
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_primaryDark, _primaryColor],
            ).createShader(bounds),
            child: const Text(
              "Create Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start your journey to financial freedom",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _textGrey,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //           FORM CARD & INPUTS
  // ══════════════════════════════════════════

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Email Address", Icons.mail_outline_rounded),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            hintText: "you@example.com",
            prefixIcon: Icons.mail_outline_rounded,
            hasFocus: _emailHasFocus,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),

          const SizedBox(height: 20),

          _buildLabel("Password", Icons.lock_outline_rounded),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hintText: "Create a password",
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            isVisible: _isPasswordVisible,
            hasFocus: _passwordHasFocus,
            enabled: !_isLoading,
            onVisibilityToggle: () {
              HapticFeedback.selectionClick();
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),

          const SizedBox(height: 20),

          _buildLabel("Confirm Password", Icons.lock_reset_rounded),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmFocus,
            hintText: "Repeat password",
            prefixIcon: Icons.lock_reset_rounded,
            isPassword: true,
            isVisible: _isConfirmPasswordVisible,
            hasFocus: _confirmHasFocus,
            enabled: !_isLoading,
            onVisibilityToggle: () {
              HapticFeedback.selectionClick();
              setState(() =>
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
            },
            onSubmitted: (_) => _handleSignup(),
          ),

          const SizedBox(height: 32),

          _buildSignupButton(),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _primaryColor.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textDark,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    required bool hasFocus,
    bool isPassword = false,
    bool isVisible = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onVisibilityToggle,
    Function(String)? onSubmitted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: hasFocus
            ? _primaryColor.withValues(alpha: 0.03)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus
              ? _primaryColor.withValues(alpha: 0.5)
              : _inputBorder,
          width: hasFocus ? 1.5 : 1,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _textDark,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: _textGrey.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              prefixIcon,
              color: hasFocus ? _primaryColor : _textGrey,
              size: 20,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      key: ValueKey(isVisible),
                      color: hasFocus ? _primaryColor : _textGrey,
                      size: 20,
                    ),
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //           BUTTONS & LINKS
  // ══════════════════════════════════════════

  Widget _buildSignupButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: GestureDetector(
        onTapDown: (_) => _buttonController.forward(),
        onTapUp: (_) {
          _buttonController.reverse();
          _handleSignup();
        },
        onTapCancel: () => _buttonController.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? LinearGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.6),
                      _accentColor.withValues(alpha: 0.6),
                    ],
                  )
                : const LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      key: const ValueKey('text'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Already have an account? ",
            style: TextStyle(
              color: _textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    Navigator.pushReplacement(
                      context,
                      _createFlipRoute(const LoginScreen(), leftToRight: true),
                    );
                  },
            child: const Text(
              "Sign In",
              style: TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}