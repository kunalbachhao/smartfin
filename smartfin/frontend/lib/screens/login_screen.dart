// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_services.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // ── Brand Colors ──
  static const Color _primaryColor = Color(0xFF00796B);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _accentColor = Color(0xFF26A69A);
  static const Color _surfaceColor = Color(0xFFF5FFFE);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF888888);
  static const Color _inputBorder = Color(0xFFE8E8E8);
  static const Color _errorColor = Color(0xFFE53935);

  // ── Animation Controllers ──
  late AnimationController _backgroundAnimController;
  late AnimationController _fadeSlideController;
  late AnimationController _headerController;
  late AnimationController _buttonController;

  late Animation<double> _headerScale;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScale;

  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;

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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _fadeSlideController,
            curve: Curves.easeOutCubic,
          ),
        );

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

    _emailFocus.addListener(
      () => setState(() => _emailHasFocus = _emailFocus.hasFocus),
    );
    _passwordFocus.addListener(
      () => setState(() => _passwordHasFocus = _passwordFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    _backgroundAnimController.dispose();
    _fadeSlideController.dispose();
    _headerController.dispose();
    _buttonController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
              child: Opacity(opacity: curve.clamp(0.0, 1.0), child: child),
            );
          },
          child: child,
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      HapticFeedback.heavyImpact();
      _showMessage("All fields are required");
      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      HapticFeedback.heavyImpact();
      _showMessage("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await ApiService.login(email, password);

    if (mounted) setState(() => _isLoading = false);

    if (result['success']) {
      HapticFeedback.mediumImpact();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.pushReplacement(
        context,
        _createFlipRoute(const DashboardScreen()),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // ── TITLE & SUBTITLE ──
                          _buildHeader(),

                          const SizedBox(height: 30),

                          // ── FORM CARD ──
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildFormCard(),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── SIGN UP LINK ──
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildSignUpLink(),
                          ),

                          const SizedBox(height: 24),

                          // ── PRIVACY FOOTER ──
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildPrivacyFooter(),
                          ),
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
                  Icons.account_balance_wallet_rounded,
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
              top: -80 + math.sin(value * 2 * math.pi) * 12,
              right: -50 + math.cos(value * 2 * math.pi) * 8,
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.07),
                      _primaryColor.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100 + math.cos(value * 2 * math.pi) * 15,
              left: -70 + math.sin(value * 2 * math.pi) * 10,
              child: Container(
                height: 280,
                width: 280,
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
              "Welcome Back",
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
            "Sign in to continue managing your finances",
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
  //           FORM CARD
  // ══════════════════════════════════════════

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.08)),
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
          ),

          const SizedBox(height: 24),

          _buildLabel("Password", Icons.lock_outline_rounded),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hintText: "Enter your password",
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            isVisible: _isPasswordVisible,
            hasFocus: _passwordHasFocus,
            enabled: !_isLoading,
            onVisibilityToggle: () {
              HapticFeedback.selectionClick();
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Forgot Password?",
                style: TextStyle(
                  fontSize: 13,
                  color: _primaryColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildLoginButton(),
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
          color: hasFocus ? _primaryColor.withValues(alpha: 0.5) : _inputBorder,
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        onSubmitted: (_) {
          if (!isPassword) {
            _passwordFocus.requestFocus();
          } else {
            _handleLogin();
          }
        },
      ),
    );
  }

  Widget _buildLoginButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: GestureDetector(
        onTapDown: (_) => _buttonController.forward(),
        onTapUp: (_) {
          _buttonController.reverse();
          _handleLogin();
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
                          "Sign In",
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

  Widget _buildSignUpLink() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
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
                    Navigator.push(
                      context,
                      _createFlipRoute(const SignUpScreen()),
                    );
                  },
            child: const Text(
              "Sign Up",
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

  Widget _buildPrivacyFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            "Secured with end-to-end encryption",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
