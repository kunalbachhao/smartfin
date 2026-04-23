import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/finance_provider.dart';
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    // ── Loading state ──────────────────────────────────────────────────────
    if (provider.isLoadingAnalytics && provider.analyticsData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              const SizedBox(height: 10),
              const _Header(),
              const SizedBox(height: 20),
              const _SegmentedControl(),
              const SizedBox(height: 20),

              // ── Error banner ─────────────────────────────────────────────
              if (provider.analyticsError != null)
                _AnalyticsErrorBanner(
                  message: provider.analyticsError!,
                  onRetry: provider.loadAnalytics,
                ),

              _TitleSection(
                netPerformance: provider.netPerformanceFormatted,
                totalBalance: provider.totalBalanceFormatted,
              ),
              const SizedBox(height: 20),
              _OverviewCard(
                monthlyUsageRatio: provider.monthlyUsageRatio,
                legendEntries: provider.legendEntries,
              ),
              const SizedBox(height: 20),
              _SpendingCard(categories: provider.spendingCategories),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 22),
        const SizedBox(width: 12),
        const Text('SmartFin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
      ],
    );
  }
}

// ── Segmented control (stateful so taps work) ─────────────────────────────────

class _SegmentedControl extends StatefulWidget {
  const _SegmentedControl();

  @override
  State<_SegmentedControl> createState() => _SegmentedControlState();
}

class _SegmentedControlState extends State<_SegmentedControl> {
  int _selected = 0;
  static const _labels = ['Week', 'Month', 'Year'];

  // Fix #19: compute the date range for each segment and reload analytics.
  void _onSegmentTap(int i) {
    if (i == _selected) return;
    setState(() => _selected = i);

    final now  = DateTime.now();
    DateTime from;
    switch (i) {
      case 0: // Week
        from = now.subtract(const Duration(days: 7));
      case 1: // Month
        from = DateTime(now.year, now.month, 1);
      case 2: // Year
        from = DateTime(now.year, 1, 1);
      default:
        from = DateTime(now.year, now.month, 1);
    }
    context.read<FinanceProvider>().loadAnalytics(from: from, to: now);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == _selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onSegmentTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Title section ─────────────────────────────────────────────────────────────

class _TitleSection extends StatelessWidget {
  final String netPerformance;
  final String totalBalance;

  const _TitleSection({required this.netPerformance, required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Net performance: $netPerformance'),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(totalBalance,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 4),
            const Text('TOTAL BALANCE', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

// ── Overview card with animated circular indicator ────────────────────────────

class _OverviewCard extends StatelessWidget {
  final double monthlyUsageRatio;
  final List<LegendEntry> legendEntries;

  const _OverviewCard({required this.monthlyUsageRatio, required this.legendEntries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OVERVIEW',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: monthlyUsageRatio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final label = '${(value * 100).toStringAsFixed(0)}%';
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.blue,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Monthly'),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ...legendEntries.map((e) => _LegendRow(entry: e)),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final LegendEntry entry;
  const _LegendRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: entry.color),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.title)),
          Text(entry.amount, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Spending card with animated bars ─────────────────────────────────────────

class _SpendingCard extends StatelessWidget {
  final List<SpendingCategory> categories;
  const _SpendingCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SPENDING BY CATEGORY',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...categories.map((c) => CategoryBar(c.title, c.amount, c.progress, c.color)),
        ],
      ),
    );
  }
}

// ── CategoryBar — animated linear progress ────────────────────────────────────

class CategoryBar extends StatelessWidget {
  final String title;
  final String amount;
  final double progress;
  final Color color;

  const CategoryBar(this.title, this.amount, this.progress, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(title)), Text(amount)]),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SpendingCard kept as public class for tests ───────────────────────────────

class SpendingCard extends StatelessWidget {
  final List<SpendingCategory> categories;
  const SpendingCard({super.key, required this.categories});

  @override
  Widget build(BuildContext context) => _SpendingCard(categories: categories);
}

BoxDecoration _cardDecoration() =>
    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16));

// ── BottomNavBar kept for backward compat with tests ─────────────────────────

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: Colors.teal,
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

class _AnalyticsErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AnalyticsErrorBanner({required this.message, required this.onRetry});

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
