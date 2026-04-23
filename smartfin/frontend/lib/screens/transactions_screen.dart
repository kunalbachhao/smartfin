import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/finance_provider.dart';
import 'transaction_detail_screen.dart';

class SmartFinScreen extends StatelessWidget {
  const SmartFinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final transactions = provider.transactions;

    // ── Loading state ──────────────────────────────────────────────────────
    if (provider.isLoadingTransactions && transactions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Build grouped list: [sectionLabel, tx, tx, sectionLabel, tx, ...]
    final List<_ListItem> items = [];
    final List<String> seenLabels = [];
    for (final t in transactions) {
      if (!seenLabels.contains(t.sectionLabel)) {
        seenLabels.add(t.sectionLabel);
        items.add(_ListItem.header(t.sectionLabel));
      }
      items.add(_ListItem.transaction(t));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Header(),
              const SizedBox(height: 20),
              const _SearchBar(),
              const SizedBox(height: 20),

              // ── Error banner ───────────────────────────────────────────
              if (provider.transactionsError != null)
                _TxErrorBanner(
                  message: provider.transactionsError!,
                  onRetry: provider.loadTransactions,
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.loadTransactions,
                  child: transactions.isEmpty
                      ? const _EmptyTransactions()
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item.isHeader) {
                              return _FadeInItem(
                                index: index,
                                child: SectionTitle(title: item.label!),
                              );
                            }
                            final tx = item.transaction!;
                            return _FadeInItem(
                              index: index,
                              child: _DismissibleTile(transaction: tx),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple data class to unify headers + transactions in one list ─────────────

class _ListItem {
  final String? label;
  final TransactionModel? transaction;

  const _ListItem.header(this.label) : transaction = null;
  const _ListItem.transaction(this.transaction) : label = null;

  bool get isHeader => label != null;
}

// ── Staggered fade-in wrapper ─────────────────────────────────────────────────

class _FadeInItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _FadeInItem({required this.index, required this.child});

  @override
  State<_FadeInItem> createState() => _FadeInItemState();
}

class _FadeInItemState extends State<_FadeInItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Total duration covers both the stagger offset and the actual animation.
    // We start the controller immediately but begin the visible animation
    // only after the stagger portion has elapsed — no Future.delayed needed.
    const animDuration = Duration(milliseconds: 350);
    final staggerMs = (widget.index * 40).clamp(0, 300);
    final totalMs = staggerMs + animDuration.inMilliseconds;

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    // Map the visible animation to the tail portion of the controller range.
    final start = staggerMs / totalMs;
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, 1.0, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Dismissible tile wrapping TransactionTile ─────────────────────────────────

class _DismissibleTile extends StatelessWidget {
  final TransactionModel transaction;
  const _DismissibleTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // Fix #17: use the unique backend id as the key to prevent duplicate-key
      // errors when two transactions have identical title/amount/subtitle.
      key: ValueKey(transaction.id.isNotEmpty
          ? transaction.id
          : '${transaction.title}_${transaction.amount}_${transaction.subtitle}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: Text('Remove "${transaction.title}" from your history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        context.read<FinanceProvider>().removeTransaction(transaction);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${transaction.title} removed'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: TransactionTile(
        icon: transaction.icon,
        title: transaction.title,
        subtitle: transaction.subtitle,
        amount: transaction.amount,
        isIncome: transaction.isIncome,
        color: transaction.color,
        onTap: () => Navigator.push(
          context,
          _slideRoute(TransactionDetailScreen(transaction: transaction)),
        ),
      ),
    );
  }
}

// ── Slide-up page route ───────────────────────────────────────────────────────

PageRoute<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, _, child) {
        final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 22, backgroundColor: Colors.grey),
        const SizedBox(width: 12),
        const Text('SmartFin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const TextField(
              decoration: InputDecoration(
                icon: Icon(Icons.search),
                hintText: 'Search transactions',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.tune),
        ),
      ],
    );
  }
}

// ── Public widgets (kept for tests) ──────────────────────────────────────────

class Header extends StatelessWidget {
  const Header({super.key});
  @override
  Widget build(BuildContext context) => const _Header();
}

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});
  @override
  Widget build(BuildContext context) => const _SearchBar();
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title,
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final bool isIncome;
  final Color color;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Transactions'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

class _TxErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _TxErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('No transactions yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
