import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Define the features based on the Project Report
  final List<Map<String, dynamic>> _features = [
    {
      "title": "Master Your Money",
      "desc": "Track expenses, manage allowances, and stick to your budget with our smart ledger.",
      "icon": Icons.account_balance_wallet_rounded,
    },
    {
      "title": "AI Financial Coach",
      "desc": "Our AI monitors your spending velocity and alerts you to 'Slow Down' before you go broke.",
      "icon": Icons.psychology_rounded,
    },
    {
      "title": "Gamified Analytics",
      "desc": "Visualize your habits with interactive charts and earn haptic rewards for saving.",
      "icon": Icons.pie_chart_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Define brand colors
    final Color primaryColor = const Color(0xFF00796B);
    final Color accentColor = Colors.teal.shade50;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. SKIP BUTTON (Top Right)
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _navigateToLogin(context),
                child: Text(
                  "Skip",
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. LOGO / BRANDING
            Text(
              "SMARTFIN",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: primaryColor,
              ),
            ),

            // 3. SLIDER SECTION
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _features.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Circle Background for Icon
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _features[index]['icon'],
                            size: 80,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Title
                        Text(
                          _features[index]['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          _features[index]['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 4. INDICATOR DOTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 5. ACTION BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    if (_currentPage == _features.length - 1) {
                      _navigateToLogin(context);
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == _features.length - 1 ? "Get Started" : "Next",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}