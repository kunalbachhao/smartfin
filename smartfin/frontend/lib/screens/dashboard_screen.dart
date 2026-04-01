import 'dart:convert';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stats_screen.dart';
import 'transactions.dart';

// ── Background Handler ──
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  debugPrint("Background SMS: ${message.body}");
}

// ── Dashboard Screen ──
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final Telephony telephony = Telephony.instance;

  String _status = "Waiting for Bank SMS...";
  List<Transaction> _transactions = [];
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _loadTransactions();
    _initSmsListener();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── PERSISTENCE ──
  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('transactions') ?? [];
    setState(() {
      _transactions = data
          .map((e) => Transaction.fromJson(jsonDecode(e)))
          .toList();
      if (_transactions.isNotEmpty) {
        _status = "Last: ${_transactions.first.type} detected";
      }
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _transactions.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('transactions', data);
  }

  // ── SMS LISTENER ──
  void _initSmsListener() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != true) {
      setState(() => _status = "❌ SMS Permission Denied");
      return;
    }

    setState(() {
      if (_transactions.isEmpty) _status = "✅ Listening for Bank SMS...";
    });

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) => _processMessage(message),
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  // ── MULTIPLE BANK FORMAT SUPPORT ──
  void _processMessage(SmsMessage message) {
    String body = message.body ?? "";
    String sender = message.address ?? "Unknown";

    //  bool isBank = !RegExp(r'^\+?[0-9]+$').hasMatch(sender);
    //  if (!isBank) return;

    Transaction? transaction = _tryExtract(body, sender);

    if (transaction != null) {
      setState(() {
        _transactions.insert(0, transaction);
        if (_transactions.length > 50) _transactions.removeLast();
        _status = "${transaction.type} detected!";
      });
      _saveTransactions();
      _animController.forward(from: 0);
    } else {
      debugPrint("Bank SMS detected but no pattern matched.");
    }
  }

  Transaction? _tryExtract(String body, String sender) {
    final amount = extractAmount(body);
    final type = extractType(body);

    if (amount == null || type == null) return null;

    final account = extractAccount(body);

    return Transaction(
      type: type,
      amount: amount,
      sender: sender,
      accountDigits: account,
      dateTime: DateTime.now(),
      category: 'Salary',
    );
  }

  double? extractAmount(String body) {
    final match = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(body);

    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  String? extractType(String body) {
    final lower = body.toLowerCase();

    if (lower.contains("debit") ||
        lower.contains("spent") ||
        lower.contains("withdrawn")) {
      return "debited";
    }
    if (lower.contains("credit") ||
        lower.contains("received") ||
        lower.contains("deposited")) {
      return "credited";
    }
    return null;
  }

  String extractAccount(String body) {
    final match = RegExp(
      r'(?:A/c|Acct|Account)[^\d]*(\d{4})',
      caseSensitive: false,
    ).firstMatch(body);

    if (match != null) return match.group(1)!;

    final fallback = RegExp(r'[\*Xx]{2,}(\d{4})').firstMatch(body);
    if (fallback != null) return fallback.group(1)!;

    if (body.toLowerCase().contains("upi")) return "UPI";

    return "****";
  }

  // ── SUMMARY ──
  double get _totalDebited => _transactions
      .where((t) => !t.isCredit)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalCredited => _transactions
      .where((t) => t.isCredit)
      .fold(0.0, (sum, t) => sum + t.amount);

  // ── LOGOUT ──
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── CLEAR HISTORY ──
  void _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Delete all transaction records?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _transactions.clear();
        _status = "✅ Listening for Bank SMS...";
      });
      _saveTransactions();
    }
  }

  // ══════════════════════════════════════
  //               BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        elevation: 0,
        actions: [
          if (_transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: "Stats",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsScreen(transactions: _transactions),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear History",
            onPressed: _clearHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── STATUS CHIP ──
            Center(
              child: Chip(
                avatar: Icon(
                  _status.contains("❌") ? Icons.error : Icons.wifi_tethering,
                  size: 18,
                  color: _status.contains("❌") ? Colors.red : Colors.green,
                ),
                label: Text(_status),
                backgroundColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),

            // ── SUMMARY CARDS ──
            Row(
              children: [
                _buildSummaryCard(
                  title: "Total Credited",
                  amount: _totalCredited,
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  title: "Total Debited",
                  amount: _totalDebited,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── LATEST TRANSACTION (Animated) ──
            if (_transactions.isNotEmpty) ...[
              const Text(
                "Latest Transaction",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              ScaleTransition(
                scale: _scaleAnimation.drive(Tween(begin: 0.95, end: 1.0)),
                child: _buildLatestCard(_transactions.first),
              ),
              const SizedBox(height: 24),
            ],

            // ── HISTORY ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Transaction History",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  "${_transactions.length} records",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_transactions.isEmpty)
              _buildEmptyState()
            else
              ..._transactions.map((t) => _buildTransactionTile(t)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //             WIDGETS
  // ══════════════════════════════════════

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildLatestCard(Transaction t) {
    final isCredit = t.isCredit;
    final color = isCredit ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCredit ? "💰 CREDITED" : "💸 DEBITED",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          Text(
            "₹${_formatNumber(t.amount)}",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _detailChip(Icons.account_balance, "A/C: ${t.accountDigits}"),
              _detailChip(Icons.sms, t.sender),
              _detailChip(
                Icons.access_time,
                DateFormat('hh:mm a').format(t.dateTime),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildTransactionTile(Transaction t) {
    final isCredit = t.isCredit;
    final color = isCredit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          "${isCredit ? "+" : "-"} ₹${_formatNumber(t.amount)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          "${t.sender}  •  A/C: ${t.accountDigits}",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('dd MMM').format(t.dateTime),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              DateFormat('hh:mm a').format(t.dateTime),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No transactions yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Bank SMS will appear here automatically",
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return NumberFormat('#,##,###', 'en_IN').format(value.toInt());
    }
    return NumberFormat('#,##,###.00', 'en_IN').format(value);
  }
}
