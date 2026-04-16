import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const AnalyticsApp());
}

class AnalyticsApp extends StatelessWidget {
  const AnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFin Analytics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00488D),
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00488D),
          secondary: Color(0xFF006A6A),
          tertiary: Color(0xFF674000),
          surface: Color(0xFFF7F9FB),
          error: Color(0xFFBA1A1A),
        ),
      ),
      home: const AnalyticsScreen(),
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedNavIndex = 1; // Analytics is selected
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 88),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Range Selector
                      DateRangeSelector(
                        selectedIndex: _selectedPeriod,
                        onChanged: (index) {
                          setState(() {
                            _selectedPeriod = index;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      // Header Stats
                      const AnalyticsHeader(),
                      const SizedBox(height: 40),
                      
                      // Donut Chart Overview
                      const DonutChartCard(),
                      const SizedBox(height: 48),
                      
                      // Spending by Category
                      const SpendingByCategoryCard(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TopAppBar(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedNavIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
      ),
    );
  }
}

// Top App Bar Component
class TopAppBar extends StatelessWidget {
  const TopAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha:0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFECEEF0),
                  backgroundImage: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAphaLxVP2gm01WHoI-0e-dG-JK4dP-5aJTiNTQiJPfTKzcZmENV1m57WGvWyYHFieLaYUoLj8YRbYhgECcEW8YB0fjfKr4Qc3KwboqPaU-Ei8usnJCsKv2A7k2Zc3RdKGI8ZzQBZO2xMWjkgLZfa_juHh1jfWfOmTkX2q1JcTsCLpP1Tjt9yc0GojnI25GIXrNu4cIgUvJ3L4W7OQ3kIlDfQEcr3Dn0PcFgDXpoJQVzTRiemqouco-LlnPekHeUMphVn30_cl0L0M',
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'SmartFin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Date Range Selector Component
class DateRangeSelector extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const DateRangeSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: PeriodButton(
              label: 'Week',
              isSelected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: PeriodButton(
              label: 'Month',
              isSelected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
          Expanded(
            child: PeriodButton(
              label: 'Year',
              isSelected: selectedIndex == 2,
              onTap: () => onChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}

class PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PeriodButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF00488D) : const Color(0xFF424752),
          ),
        ),
      ),
    );
  }
}

// Analytics Header Component
class AnalyticsHeader extends StatelessWidget {
  const AnalyticsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Analytics',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF191C1E),
                letterSpacing: -0.5,
                fontFamily: 'Manrope',
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Net performance: +12.4%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424752),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text(
              '\$14,250.00',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00488D),
                letterSpacing: -0.5,
                fontFamily: 'Manrope',
              ),
            ),
            SizedBox(height: 4),
            Text(
              'TOTAL BALANCE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006A6A),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Donut Chart Card Component
class DonutChartCard extends StatelessWidget {
  const DonutChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC2C6D4).withValues(alpha:0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OVERVIEW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424752),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),
          
          // Donut Chart
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(160, 160),
                    painter: DonutChartPainter(),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Monthly',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF424752),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '68%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00488D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Legend
          Column(
            children: [
              LegendItem(
                color: const Color(0xFF00488D),
                label: 'Fixed Costs',
                amount: '\$2,400',
              ),
              const SizedBox(height: 12),
              LegendItem(
                color: const Color(0xFF006A6A),
                label: 'Lifestyle',
                amount: '\$1,120',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 16.0;

    // Background circle
    final backgroundPaint = Paint()
      ..color = const Color(0xFFECEEF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Primary segment (70%)
    final primaryPaint = Paint()
      ..color = const Color(0xFF00488D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * 0.70,
      false,
      primaryPaint,
    );

    // Secondary segment (25%)
    final secondaryPaint = Paint()
      ..color = const Color(0xFF006A6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2 + 2 * math.pi * 0.70,
      2 * math.pi * 0.25,
      false,
      secondaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF424752),
              ),
            ),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF191C1E),
          ),
        ),
      ],
    );
  }
}

// Spending by Category Card Component
class SpendingByCategoryCard extends StatelessWidget {
  const SpendingByCategoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC2C6D4).withValues(alpha:0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'SPENDING BY CATEGORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424752),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 32),
          CategoryProgressBar(
            label: 'Food & Drinks',
            amount: '\$850.00',
            progress: 0.45,
            color: Color(0xFF00488D),
          ),
          SizedBox(height: 32),
          CategoryProgressBar(
            label: 'Rent',
            amount: '\$1,600.00',
            progress: 0.85,
            color: Color(0xFF006A6A),
          ),
          SizedBox(height: 32),
          CategoryProgressBar(
            label: 'Electronics',
            amount: '\$420.00',
            progress: 0.22,
            color: Color(0xFF005DB5),
          ),
          SizedBox(height: 32),
          CategoryProgressBar(
            label: 'Groceries',
            amount: '\$580.00',
            progress: 0.31,
            color: Color(0xFF875500),
          ),
          SizedBox(height: 32),
          CategoryProgressBar(
            label: 'Transport',
            amount: '\$320.00',
            progress: 0.17,
            color: Color(0xFF727783),
          ),
        ],
      ),
    );
  }
}

class CategoryProgressBar extends StatelessWidget {
  final String label;
  final String amount;
  final double progress;
  final Color color;

  const CategoryProgressBar({
    super.key,
    required this.label,
    required this.amount,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: const Color(0xFFECEEF0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// Custom Bottom Navigation Bar
class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavBarItem(
                icon: Icons.home,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onItemSelected(0),
              ),
              NavBarItem(
                icon: Icons.insights,
                label: 'Analytics',
                isSelected: selectedIndex == 1,
                onTap: () => onItemSelected(1),
              ),
              NavBarItem(
                icon: Icons.receipt_long,
                label: 'Transactions',
                isSelected: selectedIndex == 2,
                onTap: () => onItemSelected(2),
              ),
              NavBarItem(
                icon: Icons.person,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () => onItemSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF7AF2F2).withValues(alpha:0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF164E63)
                    : const Color(0xFF94A3B8),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF164E63)
                      : const Color(0xFF94A3B8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}