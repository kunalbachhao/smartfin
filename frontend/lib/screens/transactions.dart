import 'package:flutter/material.dart';

void main() {
  runApp(const TransactionsApp());
}

class TransactionsApp extends StatelessWidget {
  const TransactionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFin - Transactions',
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
      home: const TransactionsScreen(),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _selectedNavIndex = 2; // Transactions is selected

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
                    children: [
                      // Search & Filter Section
                      const SearchFilterSection(),
                      const SizedBox(height: 32),
                      
                      // Transaction Timeline
                      TransactionTimeline(),
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
                  backgroundImage: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCMNRmoRP3kEKGzP2ZqRw1sToR2iehZi4s-mUAebtE1RXe15hguPsn9yTCqwCQCfwBGsDt5sLozuo3V0en04Pjb54U9TgCOdibiq3BtAeuHnR8RKGtsb7tNjLlfG_dDLpILb1Hm4GDqQBbcI5y1Qhr9roZ73RGXJ0GPxM0boXJcHX5WW3k26_xx8DbSYQnyr4zxTLGfHliLxn_n16Hgz7cnOc5mn0pAfKcbSINS1c_KI4PdWotqYABpJfGCV-OW04gJgYPNrnmEuM8',
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'SmartFin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: -0.5,
                    fontFamily: 'Manrope',
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

// Search & Filter Section
class SearchFilterSection extends StatelessWidget {
  const SearchFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFC2C6D4).withValues(alpha:0.2),
              ),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search transactions',
                hintStyle: TextStyle(color: const Color(0xFF727783)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF727783),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC2C6D4).withValues(alpha:0.2),
            ),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.filter_list,
              color: Color(0xFF00488D),
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

// Transaction Timeline Component
class TransactionTimeline extends StatelessWidget {
  TransactionTimeline({super.key});

  final List<TransactionGroup> groups = [
    TransactionGroup(
      title: 'Today',
      transactions: [
        Transaction(
          icon: Icons.shopping_cart,
          iconBgColor: const Color(0xFF7AF2F2),
          iconColor: const Color(0xFF006E6E),
          title: 'Whole Foods Market',
          subtitle: '14:30 • Groceries',
          amount: '-\$84.20',
          isExpense: true,
        ),
        Transaction(
          icon: Icons.payments,
          iconBgColor: const Color(0xFF005FB8),
          iconColor: const Color(0xFFCADCFF),
          title: 'Freelance Payment',
          subtitle: '09:15 • Income',
          amount: '+\$1,250.00',
          isExpense: false,
        ),
      ],
    ),
    TransactionGroup(
      title: 'Yesterday',
      transactions: [
        Transaction(
          icon: Icons.local_taxi,
          iconBgColor: const Color(0xFFFFDDB8),
          iconColor: const Color(0xFF653E00),
          title: 'Uber Trip',
          subtitle: '21:40 • Transport',
          amount: '-\$22.50',
          isExpense: true,
        ),
        Transaction(
          icon: Icons.subscriptions,
          iconBgColor: const Color(0xFFECEEF0),
          iconColor: const Color(0xFF424752),
          title: 'Netflix Premium',
          subtitle: '00:01 • Entertainment',
          amount: '-\$19.99',
          isExpense: true,
        ),
      ],
    ),
    TransactionGroup(
      title: 'July 2024',
      transactions: [
        Transaction(
          icon: Icons.apartment,
          iconBgColor: const Color(0xFF7AF2F2),
          iconColor: const Color(0xFF006E6E),
          title: 'Monthly Rent',
          subtitle: 'Jul 31 • Housing',
          amount: '-\$2,400.00',
          isExpense: true,
        ),
        Transaction(
          icon: Icons.savings,
          iconBgColor: const Color(0xFF005FB8),
          iconColor: const Color(0xFFCADCFF),
          title: 'Dividend Payment',
          subtitle: 'Jul 28 • Investments',
          amount: '+\$45.12',
          isExpense: false,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: groups.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                group.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF727783),
                  letterSpacing: 2,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
            Column(
              children: group.transactions.map((transaction) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TransactionItem(transaction: transaction),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],
        );
      }).toList(),
    );
  }
}

// Transaction Item Component
class TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const TransactionItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.icon,
                  color: transaction.iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1E),
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF727783),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                transaction.amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: transaction.isExpense
                      ? const Color(0xFFBA1A1A)
                      : const Color(0xFF006A6A),
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ),
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
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEFF6FF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF94A3B8),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data Models
class TransactionGroup {
  final String title;
  final List<Transaction> transactions;

  TransactionGroup({
    required this.title,
    required this.transactions,
  });
}

class Transaction {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final bool isExpense;

  Transaction({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
  });
}