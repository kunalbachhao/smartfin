import 'package:flutter/material.dart';
import '../models/app_models.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.isIncome;
    final amountColor = isIncome ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B3A57)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transaction Detail',
          style: TextStyle(color: Color(0xFF1B3A57), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Amount hero card
            _AnimatedDetailCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: t.color.withOpacity(0.15),
                    child: Icon(t.icon, color: t.color, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.amount,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: amountColor),
                  ),
                  const SizedBox(height: 6),
                  Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(t.subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Details list
            _AnimatedDetailCard(
              delay: const Duration(milliseconds: 100),
              child: Column(
                children: [
                  _DetailRow(label: 'Category', value: t.category),
                  const Divider(height: 24),
                  _DetailRow(label: 'Type', value: isIncome ? 'Income' : 'Expense'),
                  const Divider(height: 24),
                  _DetailRow(label: 'Section', value: t.sectionLabel),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Status',
                    value: 'Completed',
                    valueColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3A57),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card that fades + slides up on first build.
class _AnimatedDetailCard extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedDetailCard({required this.child, this.delay = Duration.zero});

  @override
  State<_AnimatedDetailCard> createState() => _AnimatedDetailCardState();
}

class _AnimatedDetailCardState extends State<_AnimatedDetailCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.delay.inMilliseconds;
    final totalMs = delayMs + 400;

    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: totalMs));

    final start = delayMs / totalMs;
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Interval(start, 1.0, curve: Curves.easeOut)),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Interval(start, 1.0, curve: Curves.easeOut)),
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
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: widget.child,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1B3A57)),
        ),
      ],
    );
  }
}
