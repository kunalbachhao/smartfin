import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // ── Animation Controllers ──
  late AnimationController _backgroundAnimController;
  late AnimationController _iconPulseController;
  late AnimationController _buttonAnimController;
  late AnimationController _fadeInController;

  late Animation<double> _iconPulseAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _fadeInAnimation;

  // ── Brand Colors ──
  static const Color _primaryColor = Color(0xFF00796B);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _primaryLight = Color(0xFFB2DFDB);
  static const Color _accentColor = Color(0xFF26A69A);
  static const Color _surfaceColor = Color(0xFFF5FFFE);

  final List<Map<String, dynamic>> _features = [
    {
      "title": "Master Your Money",
      "desc":
          "Track expenses, manage allowances, and stick to your budget with our smart ledger.",
      "icon": Icons.account_balance_wallet_rounded,
      "gradient": [Color(0xFF00796B), Color(0xFF26A69A)],
      "bgIcon": Icons.currency_rupee_rounded,
    },
    {
      "title": "AI Financial Coach",
      "desc":
          "Our AI monitors your spending velocity and alerts you to 'Slow Down' before you go broke.",
      "icon": Icons.psychology_rounded,
      "gradient": [Color(0xFF00695C), Color(0xFF4DB6AC)],
      "bgIcon": Icons.auto_awesome_rounded,
    },
    {
      "title": "Gamified Analytics",
      "desc":
          "Visualize your habits with interactive charts and earn haptic rewards for saving.",
      "icon": Icons.pie_chart_rounded,
      "gradient": [Color(0xFF004D40), Color(0xFF80CBC4)],
      "bgIcon": Icons.emoji_events_rounded,
    },
  ];

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
      _checkLoginStatus();
    // Background floating animation
    _backgroundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Icon pulse animation
    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _iconPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _iconPulseController, curve: Curves.easeInOut),
    );

    // Button scale animation
    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );

    // Fade-in animation for initial load
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    _fadeInController.forward();
  }

  @override
  void dispose() {
    _backgroundAnimController.dispose();
    _iconPulseController.dispose();
    _buttonAnimController.dispose();
    _fadeInController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // ── 1. ANIMATED GRADIENT BACKGROUND ──
            _buildAnimatedBackground(),

            // ── 2. FLOATING DECORATIVE SHAPES ──
            _buildFloatingShapes(),

            // ── 3. MAIN CONTENT ──
            SafeArea(
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Column(
                  children: [
                    // ── TOP BAR: Logo + Skip ──
                    _buildTopBar(),

                    SizedBox(height: screenHeight * 0.02),

                    // ── PAGE VIEW SLIDER ──
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _features.length,
                        onPageChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return _buildFeaturePage(index);
                        },
                      ),
                    ),

                    // ── INDICATOR DOTS ──
                    _buildIndicatorDots(),

                    SizedBox(height: screenHeight * 0.03),

                    // ── ACTION BUTTON ──
                    _buildActionButton(),

                    SizedBox(height: screenHeight * 0.02),

                    // ── BOTTOM TEXT ──
                    _buildBottomText(),

                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //           BACKGROUND WIDGETS
  // ══════════════════════════════════════════

  Widget _buildAnimatedBackground() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _surfaceColor,
            Colors.white,
            _primaryLight.withValues(alpha: 0.15),
            _surfaceColor,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
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
            // Top-right circle
            Positioned(
              top: -60 + math.sin(value * 2 * math.pi) * 15,
              right: -40 + math.cos(value * 2 * math.pi) * 10,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.08),
                      _primaryColor.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left circle
            Positioned(
              bottom: -80 + math.cos(value * 2 * math.pi) * 20,
              left: -60 + math.sin(value * 2 * math.pi) * 12,
              child: Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentColor.withValues(alpha: 0.06),
                      _accentColor.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
            // Mid floating dot
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: 30 + math.sin(value * 3 * math.pi) * 8,
              child: Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primaryColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Another floating dot
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              right: 50 + math.cos(value * 2.5 * math.pi) * 10,
              child: Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //            TOP BAR
  // ══════════════════════════════════════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_primaryDark, _primaryColor],
                ).createShader(bounds),
                child: const Text(
                  "SMARTFIN",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white, // required for ShaderMask
                  ),
                ),
              ),
            ],
          ),

          // Skip button
          TextButton(
            onPressed: () => _navigateToLogin(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _primaryColor.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Skip",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: _primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //          FEATURE PAGE (Slider)
  // ══════════════════════════════════════════

  Widget _buildFeaturePage(int index) {
    final feature = _features[index];
    final List<Color> gradient = feature['gradient'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Animated Icon Container ──
          ScaleTransition(
            scale: _iconPulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  height: 210,
                  width: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: gradient[0].withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                ),
                // Middle ring
                Container(
                  height: 185,
                  width: 185,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradient[0].withValues(alpha: 0.05),
                  ),
                ),
                // Main icon circle with gradient
                Container(
                  height: 155,
                  width: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withValues(alpha: 0.35),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background subtle icon
                      Icon(
                        feature['bgIcon'],
                        size: 70,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      // Main icon
                      Icon(feature['icon'], size: 60, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // ── Page Number Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${index + 1} of ${_features.length}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Title ──
          Text(
            feature['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // ── Description ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              feature['desc'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //          INDICATOR DOTS
  // ══════════════════════════════════════════

  Widget _buildIndicatorDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_features.length, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          height: 10,
          width: isActive ? 32 : 10,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(colors: [_primaryColor, _accentColor])
                : null,
            color: isActive ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════
  //          ACTION BUTTON
  // ══════════════════════════════════════════

  Widget _buildActionButton() {
    final isLastPage = _currentPage == _features.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ScaleTransition(
        scale: _buttonScaleAnimation.drive(Tween(begin: 1.0, end: 0.95)),
        child: GestureDetector(
          onTapDown: (_) => _buttonAnimController.forward(),
          onTapUp: (_) {
            _buttonAnimController.reverse();
            HapticFeedback.mediumImpact();
            if (isLastPage) {
              _navigateToLogin(context);
            } else {
              _controller.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          onTapCancel: () => _buttonAnimController.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLastPage
                    ? [_primaryDark, _primaryColor]
                    : [_primaryColor, _accentColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    isLastPage ? "Get Started" : "Next",
                    key: ValueKey<bool>(isLastPage),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isLastPage
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    key: ValueKey<bool>(isLastPage),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //          BOTTOM TEXT
  // ══════════════════════════════════════════

  Widget _buildBottomText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            "Your financial data stays on your device",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //          NAVIGATION
  // ══════════════════════════════════════════

  void _navigateToLogin(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
