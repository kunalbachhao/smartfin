import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/budget_notification_service.dart';
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
      // Start listening for budget alerts after the first frame so the
      // ScaffoldMessenger is guaranteed to be in the tree.
      context.read<FinanceProvider>().addListener(_onFinanceProviderUpdate);
    });
  }

  @override
  void dispose() {
    // Remove the listener to prevent callbacks on a disposed widget.
    context.read<FinanceProvider>().removeListener(_onFinanceProviderUpdate);
    super.dispose();
  }

  /// Called on every [FinanceProvider.notifyListeners].
  /// Shows a snackbar when a new [BudgetAlert] is pending, then clears it.
  void _onFinanceProviderUpdate() {
    if (!mounted) return;
    final finance = context.read<FinanceProvider>();
    final alert   = finance.pendingAlert;
    if (alert == null) return;

    // Consume immediately so a second rebuild does not re-show the same alert.
    finance.clearPendingAlert();

    _showBudgetSnackbar(alert);
  }

  /// Displays a styled in-app snackbar for [alert].
  ///
  /// The snackbar is shown via [ScaffoldMessenger] so it floats above all
  /// tabs and is not dismissed by tab switches.
  void _showBudgetSnackbar(BudgetAlert alert) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Dismiss any existing budget snackbar before showing the new one.
    messenger.hideCurrentSnackBar();

    final color = _snackbarColorFor(alert.thresholdPct);
    final icon  = _snackbarIconFor(alert.thresholdPct);

    messenger.showSnackBar(
      SnackBar(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: color,
        duration:        const Duration(seconds: 5),
        margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BudgetNotificationService.titleFor(alert),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    BudgetNotificationService.bodyFor(alert),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  /// Snackbar background colour matching the alert severity.
  static Color _snackbarColorFor(int pct) {
    if (pct >= 100) return const Color(0xFFD32F2F); // red
    if (pct >= 90)  return const Color(0xFFE64A19); // deep orange
    if (pct >= 75)  return const Color(0xFFF57C00); // orange
    if (pct >= 50)  return const Color(0xFFF9A825); // amber
    return              const Color(0xFF388E3C);    // green (25%)
  }

  /// Icon matching the alert severity.
  static IconData _snackbarIconFor(int pct) {
    if (pct >= 100) return Icons.error_outline;
    if (pct >= 90)  return Icons.warning_amber_rounded;
    if (pct >= 75)  return Icons.warning_outlined;
    if (pct >= 50)  return Icons.info_outline;
    return              Icons.check_circle_outline;
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
