import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transactions.dart';
class StatsScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const StatsScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final totalCredit = transactions
        .where((t) => t.isCredit)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalDebit = transactions
        .where((t) => !t.isCredit)
        .fold(0.0, (sum, t) => sum + t.amount);

    final monthlySummary = getMonthlySummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── TOTAL CARDS ──
          _buildStatCard("Total Credited", totalCredit, Colors.green),
          const SizedBox(height: 12),
          _buildStatCard("Total Debited", totalDebit, Colors.red),
          const SizedBox(height: 24),

          // ── MONTHLY SUMMARY ──
          const Text(
            "Monthly Summary",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...monthlySummary.entries.map((entry) {
            final month = entry.key;
            final credit = entry.value["credit"]!;
            final debit = entry.value["debit"]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(month),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Credit: ₹${_formatNumber(credit)}",
                        style: const TextStyle(color: Colors.green)),
                    Text("Debit: ₹${_formatNumber(debit)}",
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // ── CATEGORY WISE PIE CHART ──
          _buildCategoryPieChart(),
        ],
      ),
    );
  }

  // ── TOTAL CARD WIDGET ──
  Widget _buildStatCard(String title, double amount, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            "₹${_formatNumber(amount)}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── MONTHLY SUMMARY CALCULATION ──
  Map<String, Map<String, double>> getMonthlySummary() {
    Map<String, Map<String, double>> summary = {};

    for (var t in transactions) {
      String month = DateFormat('MMM yyyy').format(t.dateTime);
      summary[month] ??= {"credit": 0.0, "debit": 0.0};

      if (t.isCredit) {
        summary[month]!["credit"] = summary[month]!["credit"]! + t.amount;
      } else {
        summary[month]!["debit"] = summary[month]!["debit"]! + t.amount;
      }
    }

    return summary;
  }

  // ── CATEGORY WISE DATA ──
  Map<String, double> getCategoryExpenses() {
    Map<String, double> data = {};
    for (var t in transactions.where((t) => !t.isCredit)) {
      data[t.category] = (data[t.category] ?? 0) + t.amount;
    }
    return data;
  }

  // ── PIE CHART WIDGET ──
  Widget _buildCategoryPieChart() {
    final categoryData = getCategoryExpenses();
    final total = categoryData.values.fold(0.0, (a, b) => a + b);

    if (categoryData.isEmpty) return const Text("No expense data.");

    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.brown
    ];

    int index = 0;
    List<PieChartSectionData> sections = categoryData.entries.map((e) {
      final value = e.value;
      final percentage = (value / total) * 100;
      final color = colors[index % colors.length];
      index++;

      return PieChartSectionData(
        color: color,
        value: value,
        title: "${percentage.toStringAsFixed(1)}%",
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Expenses by Category",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: categoryData.entries.map((e) {
                final idx = categoryData.keys.toList().indexOf(e.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: colors[idx % colors.length]),
                    const SizedBox(width: 4),
                    Text("${e.key} - ₹${_formatNumber(e.value)}")
                  ],
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  // ── NUMBER FORMAT ──
  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return NumberFormat('#,##,###', 'en_IN').format(value.toInt());
    }
    return NumberFormat('#,##,###.00', 'en_IN').format(value);
  }
}