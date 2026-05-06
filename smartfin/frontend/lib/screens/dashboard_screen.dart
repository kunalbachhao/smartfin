import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import 'transaction_detail_screen.dart';

// ── Budget colour helper (shared by card and skeleton) ────────────────────────

/// Returns the progress bar / indicator colour for a given [ratio] (0.0–1.0+).
///
/// Thresholds:
///   0 – 50 %   → green
///   50 – 75 %  → yellow / amber
///   75 – 90 %  → orange
///   90 – 100%+ → red
Color _budgetColor(double ratio) {
  final pct = ratio * 100;
  if (pct < 50)  return const Color(0xFF388E3C); // green
  if (pct < 75)  return const Color(0xFFF9A825); // amber
  if (pct < 90)  return const Color(0xFFF57C00); // orange
  return              const Color(0xFFD32F2F); // red
}

// Slide-up route reused from transactions_screen
PageRoute<T> _slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    // Show skeleton while the first load is in flight.
    if (provider.isLoading && provider.accounts.isEmpty) {
      return const _DashboardSkeleton();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 10),

              // ── Error banner ─────────────────────────────────────────────
              if (provider.accountsError != null || provider.transactionsError != null)
                _ErrorBanner(
                  message: provider.accountsError ?? provider.transactionsError!,
                  onRetry: provider.loadAll,
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "SmartFin",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3A57),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.notifications_none),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                "TOTAL EXPENDITURE",
                style: TextStyle(color: Colors.grey, letterSpacing: 1),
              ),
              const SizedBox(height: 8),

              Text(
                provider.netWorthFormatted,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4F72),
                ),
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),

              // ── Monthly Budget Insight ────────────────────────────────────
              const BudgetInsightCard(),
              const SizedBox(height: 24),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Your Accounts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("View All", style: TextStyle(color: Colors.blue)),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 140,
                child: provider.isLoadingAccounts && provider.accounts.isEmpty
                    // Accounts-only loading state (e.g. after SMS sync adds a new account)
                    ? const Center(child: CircularProgressIndicator())
                    : provider.accounts.isEmpty
                        ? _EmptyAccountsPlaceholder(onRefresh: provider.loadAccounts)
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.accounts.length,
                            itemBuilder: (context, i) => AccountCard(
                              title:   provider.accounts[i].title,
                              number:  provider.accounts[i].number,
                              balance: provider.accounts[i].balance,
                              isLast:  i == provider.accounts.length - 1,
                            ),
                          ),
              ),

              const SizedBox(height: 24),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.tune),
                ],
              ),

              const SizedBox(height: 16),

              ...provider.recentTransactions.map((t) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      _slideRoute(TransactionDetailScreen(transaction: t)),
                    ),
                    child: TransactionTile(
                      title: t.title,
                      subtitle: t.subtitle,
                      amount: t.amount,
                      color: t.color,
                    ),
                  )),

              const SizedBox(height: 20),

              // Fix #15: "Show All Activity" switches to the Transactions tab.
              // We use a callback stored in the provider to avoid tight coupling.
              GestureDetector(
                onTap: () {
                  // Trigger tab switch via a simple callback pattern.
                  // MainShell registers this callback in FinanceProvider on init.
                  context.read<FinanceProvider>().switchToTransactionsTab?.call();
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("Show All Activity", style: TextStyle(color: Colors.blue)),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

}

class AccountCard extends StatelessWidget {
  final String title;
  final String number;   // e.g. "**** 8045" or "4492" or "XX8045"
  final String balance;  // formatted, e.g. "₹1,00,000.00"
  final bool isLast;

  const AccountCard({
    super.key,
    required this.title,
    required this.number,
    required this.balance,
    this.isLast = false,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Formats any number string into "••••  XXXX" display form.
  ///
  /// Extracts the last 4 digits from whatever format is stored:
  ///   "**** 8045"  → "••••  8045"
  ///   "XX8045"     → "••••  8045"
  ///   "4492"       → "••••  4492"
  String get _maskedNumber {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return number; // fallback: show as-is
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return '••••  $last4';
  }

  /// Pick a card gradient based on the account title (bank name).
  List<Color> get _gradient {
    final t = title.toLowerCase();
    if (t.contains('hdfc'))   { return [const Color(0xFF1B3A57), const Color(0xFF2E6DA4)]; }
    if (t.contains('sbi') || t.contains('state bank')) {
      return [const Color(0xFF1A5276), const Color(0xFF2980B9)];
    }
    if (t.contains('icici'))  { return [const Color(0xFF922B21), const Color(0xFFE74C3C)]; }
    if (t.contains('axis'))   { return [const Color(0xFF6C3483), const Color(0xFF9B59B6)]; }
    if (t.contains('kotak'))  { return [const Color(0xFF784212), const Color(0xFFCA6F1E)]; }
    if (t.contains('paytm') || t.contains('phonepe') || t.contains('gpay')) {
      return [const Color(0xFF1A5276), const Color(0xFF148F77)];
    }
    // Default navy
    return [const Color(0xFF1B3A57), const Color(0xFF2C5F8A)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: EdgeInsets.only(right: isLast ? 0 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gradient.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.1),
          onTap: () {}, // reserved for future account detail screen
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bank name
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Masked account number
                Text(
                  _maskedNumber,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Balance
                Text(
                  balance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color color;

  const TransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.monetization_on, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Text(
        amount,
        style: TextStyle(
          color: amount.startsWith('+') ? Colors.green : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const NavItem({super.key, required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? Colors.blue : Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.blue : Colors.grey)),
      ],
    );
  }
}

// ── Empty accounts placeholder ────────────────────────────────────────────────

class _EmptyAccountsPlaceholder extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyAccountsPlaceholder({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 28, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No accounts yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Accounts appear after SMS sync',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact error banner with a retry button.
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

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
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── BudgetInsightCard ─────────────────────────────────────────────────────────
//
// Displays the monthly budget progress bar with colour-coded indicator,
// percentage used, and remaining amount.  Reads live data from
// [FinanceProvider] via [context.watch] so it rebuilds automatically after
// every transaction mutation.

class BudgetInsightCard extends StatelessWidget {
  const BudgetInsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    // Show a compact shimmer skeleton until the budget value has been
    // fetched from the backend or local cache.  This prevents the card
    // from briefly rendering the in-memory default (₹10,000) before the
    // real value arrives, which would cause a visible snap/flash.
    if (!provider.isBudgetLoaded) {
      return const _BudgetInsightSkeleton();
    }

    final ratio     = provider.budgetUsageRatio.clamp(0.0, 1.0);
    final pct       = provider.budgetUsagePercent;
    final color     = _budgetColor(ratio);
    final exceeded  = provider.isBudgetExceeded;
    final remaining = provider.budgetRemaining;

    // Status label changes with severity.
    final String statusLabel;
    if (pct < 50) {
      statusLabel = 'On track';
    // ignore: curly_braces_in_flow_control_structures
    } else if (pct < 75)  statusLabel = 'Monitor spending';
    // ignore: curly_braces_in_flow_control_structures
    else if (pct < 90)  statusLabel = 'Spend carefully';
    // ignore: curly_braces_in_flow_control_structures
    else if (pct < 100) statusLabel = 'Near limit';
    // ignore: curly_braces_in_flow_control_structures
    else                statusLabel = 'Budget exceeded';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Monthly Budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B3A57),
                ),
              ),
              const Spacer(),
              // Colour-coded status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Animated progress bar ────────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFEEEEEE),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Stats row ──────────────────────────────────────────
                  Row(
                    children: [
                      // Percentage used — large and colour-coded
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'used',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      // Remaining / over-budget amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            exceeded ? 'Over by' : 'Remaining',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _formatAmount(remaining.abs()),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: exceeded ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // ── Budget total line ────────────────────────────────────────────
          Row(
            children: [
              Text(
                _formatAmount(provider.currentMonthExpenses),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Text(
                ' / ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                _formatAmount(provider.monthlyBudget),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Text(
                'this month',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats a rupee amount compactly, e.g. 10000 → "₹10,000".
  static String _formatAmount(double value) {
    final abs  = value.abs();
    final sign = value < 0 ? '-' : '';
    // Use integer display when the value has no meaningful decimal part.
    final str  = abs >= 1000
        ? abs.toStringAsFixed(0)
        : abs.toStringAsFixed(2);
    final parts = str.split('.');
    final grouped = _indianGroup(parts[0]);
    return parts.length > 1 && parts[1] != '00'
        ? '$sign₹$grouped.${parts[1]}'
        : '$sign₹$grouped';
  }

  static String _indianGroup(String s) {
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest  = s.substring(0, s.length - 3);
    final buf   = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${buf.toString()},$last3';
  }
}

// ── BudgetInsightCard skeleton ────────────────────────────────────────────────
// Shown while the budget value is being fetched from the backend.
// Matches the BudgetInsightCard dimensions so there is no layout shift.

class _BudgetInsightSkeleton extends StatefulWidget {
  const _BudgetInsightSkeleton();

  @override
  State<_BudgetInsightSkeleton> createState() => _BudgetInsightSkeletonState();
}

class _BudgetInsightSkeletonState extends State<_BudgetInsightSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final shade = Color.lerp(
          const Color(0xFFE0E0E0),
          const Color(0xFFF5F5F5),
          _shimmer.value,
        )!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row skeleton
              Row(
                children: [
                  _Bone(width: 120, height: 14, color: shade),
                  const Spacer(),
                  _Bone(width: 80, height: 22, radius: 20, color: shade),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar skeleton
              _Bone(width: double.infinity, height: 10, radius: 8, color: shade),
              const SizedBox(height: 10),
              // Stats row skeleton
              Row(
                children: [
                  _Bone(width: 60, height: 28, color: shade),
                  const SizedBox(width: 6),
                  _Bone(width: 30, height: 14, color: shade),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bone(width: 60, height: 11, color: shade),
                      const SizedBox(height: 4),
                      _Bone(width: 80, height: 14, color: shade),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Footer line skeleton
              Row(
                children: [
                  _Bone(width: 100, height: 12, color: shade),
                  const Spacer(),
                  _Bone(width: 60, height: 11, color: shade),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Skeleton UI ───────────────────────────────────────────────────────────────
// Shown while the first data load is in flight. Matches the dashboard layout
// exactly so there is no layout shift when real data arrives.

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final shade = Color.lerp(
          const Color(0xFFE0E0E0),
          const Color(0xFFF5F5F5),
          _shimmer.value,
        )!;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  // Top bar
                  Row(
                    children: [
                      _Bone(width: 36, height: 36, radius: 18, color: shade),
                      const SizedBox(width: 10),
                      _Bone(width: 100, height: 16, color: shade),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Net worth label
                  _Bone(width: 120, height: 12, color: shade),
                  const SizedBox(height: 10),
                  _Bone(width: 200, height: 36, color: shade),
                  const SizedBox(height: 24),
                  // Budget insight card skeleton
                  _Bone(width: double.infinity, height: 110, radius: 20, color: shade),
                  const SizedBox(height: 28),
                  // Accounts header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Bone(width: 130, height: 16, color: shade),
                      _Bone(width: 60, height: 14, color: shade),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Account cards
                  SizedBox(
                    height: 140,
                    child: Row(
                      children: [
                        _Bone(width: 220, height: 140, radius: 20, color: shade),
                        const SizedBox(width: 12),
                        _Bone(width: 220, height: 140, radius: 20, color: shade),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Transactions header
                  _Bone(width: 160, height: 16, color: shade),
                  const SizedBox(height: 16),
                  // Transaction rows
                  for (int i = 0; i < 4; i++) ...[
                    Row(
                      children: [
                        _Bone(width: 44, height: 44, radius: 22, color: shade),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Bone(width: double.infinity, height: 14, color: shade),
                              const SizedBox(height: 6),
                              _Bone(width: 120, height: 11, color: shade),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Bone(width: 60, height: 14, color: shade),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single rounded rectangle placeholder used in the skeleton.
class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _Bone({
    required this.width,
    required this.height,
    this.radius = 8,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
