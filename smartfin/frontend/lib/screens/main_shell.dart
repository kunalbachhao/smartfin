import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'transactions_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  /// Optional starting tab index (0 = Home, 1 = Analytics, 2 = Transactions, 3 = Profile).
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late int _previousIndex;

  // Each tab gets its own Navigator so back-stack is isolated per tab.
  static const List<Widget> _tabs = [
    DashboardScreen(),
    AnalyticsScreen(),
    SmartFinScreen(),   // transactions
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex  = widget.initialIndex;
    _previousIndex = widget.initialIndex;
    // Fix #15: register the tab-switch callback so DashboardScreen can
    // navigate to Transactions without importing MainShell internals.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().switchToTransactionsTab =
          () => _onTabTap(2);
    });
  }

  // Fix #15: exposed as a non-private method so DashboardScreen can call it
  // via context.findAncestorStateOfType<_MainShellState>().
  void _onTabTap(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex  = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final goingRight = _currentIndex > _previousIndex;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final offsetIn = Tween<Offset>(
            begin: Offset(goingRight ? 0.06 : -0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetIn, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: IndexedStack(index: _currentIndex, children: _tabs),
        ),
      ),
      bottomNavigationBar: _SmartFinBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }}

class _SmartFinBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SmartFinBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),       activeIcon: Icon(Icons.home),           label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart),          activeIcon: Icon(Icons.show_chart),     label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined),activeIcon: Icon(Icons.receipt_long),  label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),      activeIcon: Icon(Icons.person),         label: 'Profile'),
        ],
      ),
    );
  }
}
