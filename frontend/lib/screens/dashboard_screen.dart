// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import '../models/transaction.dart' as models;

// Shared Transaction Display Model for UI
class DisplayTransaction {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final bool isExpense;
  final DateTime dateTime;

  DisplayTransaction({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.dateTime,
  });
}

// Transaction Group for organizing by date
class TransactionGroup {
  final String title;
  final List<DisplayTransaction> transactions;

  TransactionGroup({
    required this.title,
    required this.transactions,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  
  // Shared transaction state
  List<DisplayTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // Load transactions from SharedPreferences
  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('transactions');
    
    if (savedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedData);
        setState(() {
          _transactions = decoded.map((item) => _convertToDisplayTransaction(
            models.Transaction.fromJson(item),
          )).toList();
        });
      } catch (e) {
        debugPrint('Error loading transactions: $e');
      }
    }
    
    // Transaction loading complete
  }

  // Save transactions to SharedPreferences
  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _transactions.map((t) => _convertToModel(t).toJson()).toList(),
    );
    await prefs.setString('transactions', encoded);
  }

  // Add new transaction
  void addTransaction(DisplayTransaction transaction) {
    setState(() {
      _transactions.insert(0, transaction);
    });
    _saveTransactions();
  }

  // Convert model transaction to display transaction
  DisplayTransaction _convertToDisplayTransaction(models.Transaction model) {
    final isExpense = model.type.toLowerCase() == 'debit' || 
                      model.type.toLowerCase() == 'expense' ||
                      model.type.toLowerCase() == 'debited';
    
    return DisplayTransaction(
      icon: _getIconForCategory(model.category),
      iconBgColor: isExpense ? const Color(0xFFFFDDB8) : const Color(0xFFCADCFF),
      iconColor: isExpense ? const Color(0xFF653E00) : const Color(0xFF005FB8),
      title: model.sender,
      subtitle: '${model.dateTime.hour}:${model.dateTime.minute.toString().padLeft(2, '0')} • ${model.category}',
      amount: '${isExpense ? '-' : '+'}₹${model.amount.toStringAsFixed(2)}',
      isExpense: isExpense,
      dateTime: model.dateTime,
    );
  }

  // Convert display transaction to model
  models.Transaction _convertToModel(DisplayTransaction display) {
    return models.Transaction(
      type: display.isExpense ? 'debit' : 'credit',
      amount: double.tryParse(display.amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
      sender: display.title,
      accountDigits: '',
      dateTime: display.dateTime,
      category: display.subtitle.split('•').last.trim(),
      transactionId: '',
      bankName: '',
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'groceries':
        return Icons.shopping_cart;
      case 'transport':
      case 'travel':
        return Icons.local_taxi;
      case 'entertainment':
        return Icons.subscriptions;
      case 'housing':
      case 'rent':
        return Icons.apartment;
      case 'income':
      case 'salary':
        return Icons.payments;
      case 'investments':
        return Icons.savings;
      default:
        return Icons.receipt_long;
    }
  }

  // Get transaction groups organized by date
  List<TransactionGroup> get transactionGroups {
    final groups = <String, List<DisplayTransaction>>{};
    final now = DateTime.now();
    
    for (var transaction in _transactions) {
      final date = transaction.dateTime;
      String title;
      
      if (_isSameDay(date, now)) {
        title = 'Today';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        title = 'Yesterday';
      } else {
        title = '${_getMonthName(date.month)} ${date.year}';
      }
      
      groups.putIfAbsent(title, () => []).add(transaction);
    }
    
    return groups.entries
        .map((e) => TransactionGroup(title: e.key, transactions: e.value))
        .toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // Get summary statistics
  Map<String, double> get statsSummary {
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (var t in _transactions) {
      final amount = double.tryParse(t.amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (t.isExpense) {
        totalExpense += amount;
      } else {
        totalIncome += amount;
      }
    }
    
    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to login again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF424752)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // User cancelled logout
    if (confirm != true) return;

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00488D)),
            ),
          ),
        );
      }

      // Clear all authentication data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Remove all auth-related keys (handle missing keys gracefully)
      await prefs.remove('isLoggedIn');
      await prefs.remove('token');
      await prefs.remove('userEmail');
      await prefs.remove('userId');
      await prefs.remove('refreshToken');
      
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Navigate to WelcomeScreen and clear all previous routes
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Widget list for bottom navigation screens
  List<Widget> get _screens => [
        const HomeScreen(),
        StatsContent(
          transactions: _transactions,
          statsSummary: statsSummary,
        ),
        AddExpenseContent(
          onAddTransaction: addTransaction,
        ),
        ProfileContent(
          transactionCount: _transactions.length,
          onLogout: _handleLogout,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          if (index == 3) {
            // Profile tab - trigger logout
            _handleLogout();
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
      ),
    );
  }
}

// Home Screen Widget - extracted from original DashboardScreen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 88),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroSection(),
                    const SizedBox(height: 32),
                    const QuickActions(),
                    const SizedBox(height: 40),
                    const AccountCardsSection(),
                    const SizedBox(height: 40),
                    const RecentTransactionsSection(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Get the logout handler from parent via Builder
        Builder(
          builder: (context) {
            final dashboardState = context.findAncestorStateOfType<_DashboardScreenState>();
            return TopAppBar(onLogout: () => dashboardState?._handleLogout() ?? Future.value());
          },
        ),
      ],
    );
  }
}

// Stats/Analytics Tab Content
class StatsContent extends StatelessWidget {
  final List<DisplayTransaction> transactions;
  final Map<String, double> statsSummary;

  const StatsContent({
    super.key,
    required this.transactions,
    required this.statsSummary,
  });

  @override
  Widget build(BuildContext context) {
    final income = statsSummary['income'] ?? 0.0;
    final expense = statsSummary['expense'] ?? 0.0;
    final balance = statsSummary['balance'] ?? 0.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your financial overview',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF727783),
              ),
            ),
            const SizedBox(height: 32),
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Income',
                    amount: '₹${income.toStringAsFixed(2)}',
                    icon: Icons.arrow_upward,
                    color: const Color(0xFF006A6A),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Expense',
                    amount: '₹${expense.toStringAsFixed(2)}',
                    icon: Icons.arrow_downward,
                    color: const Color(0xFFBA1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryCard(
              title: 'Balance',
              amount: '₹${balance.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF00488D),
              fullWidth: true,
            ),
            const SizedBox(height: 32),
            // Recent Transactions Summary
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              const Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF727783),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.take(5).length,
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.iconBgColor,
                      child: Icon(t.icon, color: t.iconColor),
                    ),
                    title: Text(t.title),
                    subtitle: Text(t.subtitle),
                    trailing: Text(
                      t.amount,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.isExpense ? const Color(0xFFBA1A1A) : const Color(0xFF006A6A),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF727783),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Add Expense Tab Content
class AddExpenseContent extends StatelessWidget {
  final Function(DisplayTransaction) onAddTransaction;

  const AddExpenseContent({
    super.key,
    required this.onAddTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text(
              'Add Expense',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Record a new transaction',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF727783),
              ),
            ),
            const SizedBox(height: 32),
            // Quick Add Options
            _QuickAddButton(
              icon: Icons.shopping_cart,
              label: 'Groceries',
              color: const Color(0xFF7AF2F2),
              iconColor: const Color(0xFF006E6E),
              onTap: () => _addQuickTransaction(context, 'Groceries', 500, true),
            ),
            const SizedBox(height: 12),
            _QuickAddButton(
              icon: Icons.local_taxi,
              label: 'Transport',
              color: const Color(0xFFFFDDB8),
              iconColor: const Color(0xFF653E00),
              onTap: () => _addQuickTransaction(context, 'Transport', 200, true),
            ),
            const SizedBox(height: 12),
            _QuickAddButton(
              icon: Icons.restaurant,
              label: 'Food & Dining',
              color: const Color(0xFFE0E2EC),
              iconColor: const Color(0xFF424752),
              onTap: () => _addQuickTransaction(context, 'Food', 800, true),
            ),
            const SizedBox(height: 12),
            _QuickAddButton(
              icon: Icons.payments,
              label: 'Income / Salary',
              color: const Color(0xFFCADCFF),
              iconColor: const Color(0xFF005FB8),
              onTap: () => _addQuickTransaction(context, 'Salary', 50000, false),
            ),
          ],
        ),
      ),
    );
  }

  void _addQuickTransaction(BuildContext context, String category, double amount, bool isExpense) {
    final transaction = DisplayTransaction(
      icon: _getIconForCategory(category),
      iconBgColor: isExpense ? const Color(0xFFFFDDB8) : const Color(0xFFCADCFF),
      iconColor: isExpense ? const Color(0xFF653E00) : const Color(0xFF005FB8),
      title: category,
      subtitle: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} • $category',
      amount: '${isExpense ? '-' : '+'}₹${amount.toStringAsFixed(2)}',
      isExpense: isExpense,
      dateTime: DateTime.now(),
    );
    
    onAddTransaction(transaction);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$category ${isExpense ? 'expense' : 'income'} added!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_cart;
      case 'transport':
        return Icons.local_taxi;
      case 'food':
        return Icons.restaurant;
      case 'salary':
        return Icons.payments;
      default:
        return Icons.receipt_long;
    }
  }
}

class _QuickAddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E2EC)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF191C1E),
              ),
            ),
            const Spacer(),
            const Icon(Icons.add, color: Color(0xFF727783)),
          ],
        ),
      ),
    );
  }
}

// Profile Tab Content (shown before logout)
class ProfileContent extends StatelessWidget {
  final int transactionCount;
  final Future<void> Function() onLogout;

  const ProfileContent({
    super.key,
    required this.transactionCount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFF00488D),
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$transactionCount transactions recorded',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF727783),
              ),
            ),
            const SizedBox(height: 48),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProfileStat(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  value: '$transactionCount',
                ),
                const SizedBox(width: 32),
                _ProfileStat(
                  icon: Icons.calendar_today,
                  label: 'Member Since',
                  value: '2024',
                ),
              ],
            ),
            const SizedBox(height: 48),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onLogout(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00488D), size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF191C1E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF727783),
          ),
        ),
      ],
    );
  }
}

// Top App Bar Component
class TopAppBar extends StatelessWidget {
  final Future<void> Function() onLogout;

  const TopAppBar({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  backgroundColor: const Color(0xFFE6E8EA),
                  child: ClipOval(
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCFqGBze5NJJMBwAeka4UCPVO2rN2gXc_IidL_i9gc9QtuPiUQ7Bj1_M8vE4XRHedZjiHgfAw6JuxE8SE27_zBeD-bSL1FJHgUgjGqSazebuZ2-7hT3DmdV0UDMAcYJUWZdjGmg1qaUz5aC16docEEEtqmeaIyLVdgq0liRv61fsqO5_W2cXVdTdohMw5Ous-xnAYodhVPEg-u5vbXMplMSRLSDDZL3G8UtHIHYT41U5WOjIGIOcSpVR7HkaSDRymFWRfjXP60fIJM',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey[300]);
                      },
                    ),
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
                onTap: onLogout,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.logout_outlined,
                    color: Color(0xFF1D4ED8),
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

// Hero Section Component
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL NET WORTH',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF424752),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '\$124,592.40',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00488D),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 16,
                    color: Color(0xFF006A6A),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    '2.4%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006A6A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Quick Actions Component
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionButton(
            icon: Icons.payments,
            label: 'Pay Bill',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF7AF2F2),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF006E6E), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006E6E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Account Cards Section
class AccountCardsSection extends StatelessWidget {
  const AccountCardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Accounts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00488D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 176,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              AccountCard(
                accountType: 'Checking Account',
                accountNumber: '**** 4492',
                balance: '\$12,450.00',
                status: 'Active',
                icon: Icons.account_balance_wallet_outlined,
                backgroundColor: Color(0xFFFFFFFF),
                iconColor: Color(0xFF00488D),
                statusColor: Color(0xFF006A6A),
              ),
              SizedBox(width: 16),
              AccountCard(
                accountType: 'High-Yield Savings',
                accountNumber: '**** 8821',
                balance: '\$84,122.40',
                status: '4.50% APY',
                icon: Icons.savings_outlined,
                backgroundColor: Color(0xFFF2F4F6),
                iconColor: Color(0xFF006A6A),
                statusColor: Color(0xFF674000),
              ),
              SizedBox(width: 16),
              AccountCard(
                accountType: 'Investment Portfolio',
                accountNumber: 'ETFs & Stocks',
                balance: '\$28,020.00',
                status: '+12.4% YTD',
                icon: Icons.analytics_outlined,
                backgroundColor: Color(0xFFFFFFFF),
                iconColor: Color(0xFF674000),
                statusColor: Color(0xFF00488D),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AccountCard extends StatelessWidget {
  final String accountType;
  final String accountNumber;
  final String balance;
  final String status;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color statusColor;

  const AccountCard({
    super.key,
    required this.accountType,
    required this.accountNumber,
    required this.balance,
    required this.status,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: backgroundColor == const Color(0xFFFFFFFF)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: backgroundColor != const Color(0xFFFFFFFF)
            ? Border.all(
                color: const Color(0xFFC2C6D4).withValues(alpha:0.2),
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accountType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF424752),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accountNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF727783),
                    ),
                  ),
                ],
              ),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                balance,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Recent Transactions Section
class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune, color: Color(0xFF727783)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const TransactionItem(
          title: 'Blue Bottle Coffee',
          subtitle: 'Food & Drinks • Today, 10:45 AM',
          amount: '-\$12.50',
          type: 'Debit',
          icon: Icons.restaurant,
          iconColor: Color(0xFF006A6A),
          iconBackground: Color(0xFF7AF2F2),
          amountColor: Color(0xFF191C1E),
        ),
        const SizedBox(height: 24),
        const TransactionItem(
          title: 'Monthly Salary',
          subtitle: 'Income • Aug 01, 2024',
          amount: '+\$8,400.00',
          type: 'Direct Deposit',
          icon: Icons.payments,
          iconColor: Color(0xFF00488D),
          iconBackground: Color(0xFFD6E3FF),
          amountColor: Color(0xFF006A6A),
        ),
        const SizedBox(height: 24),
        const TransactionItem(
          title: 'Skyline Properties',
          subtitle: 'Rent • Aug 01, 2024',
          amount: '-\$2,200.00',
          type: 'ACH Transfer',
          icon: Icons.home,
          iconColor: Color(0xFF674000),
          iconBackground: Color(0xFFFFDDB8),
          amountColor: Color(0xFF191C1E),
        ),
        const SizedBox(height: 24),
        const TransactionItem(
          title: 'Apple Store',
          subtitle: 'Electronics • Jul 28, 2024',
          amount: '-\$199.00',
          type: 'Apple Pay',
          icon: Icons.shopping_bag,
          iconColor: Color(0xFF424752),
          iconBackground: Color(0xFFE0E3E5),
          amountColor: Color(0xFF191C1E),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Text(
                  'Show All Activity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00488D),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TransactionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String type;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color amountColor;

  const TransactionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF424752),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                type.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF727783),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
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