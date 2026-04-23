import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../services/sms_database.dart';
import '../services/sms_storage_helper.dart';
import '../services/sms_sync_service.dart';

// ── Palette (matches project-wide colours) ────────────────────────────────────
const _kBg        = Color(0xFFF4F6F9);
const _kNavy      = Color(0xFF1B3A57);
const _kCardWhite = Colors.white;

class SmsSyncScreen extends StatefulWidget {
  const SmsSyncScreen({super.key});

  @override
  State<SmsSyncScreen> createState() => _SmsSyncScreenState();
}

class _SmsSyncScreenState extends State<SmsSyncScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool          _isSyncing        = false;
  PermissionStatus? _permStatus;
  DateTime?     _lastSyncTime;
  int           _totalTransactions = 0;
  String        _syncStatusLabel  = 'Idle';
  Color         _syncStatusColor  = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadStatus() async {
    final perm  = await Permission.sms.status;
    final last  = await SmsStorageHelper.getLastSyncTime();
    final txns  = await SmsDatabase.instance.getAllTransactions();

    if (!mounted) return;
    setState(() {
      _permStatus       = perm;
      _lastSyncTime     = last;
      _totalTransactions = txns.length;
      _syncStatusLabel  = _deriveSyncLabel(last);
      _syncStatusColor  = _deriveSyncColor(last);
    });
  }

  String _deriveSyncLabel(DateTime? last) {
    if (last == null) return 'Never synced';
    final diff = DateTime.now().difference(last);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _deriveSyncColor(DateTime? last) {
    if (last == null) return Colors.grey;
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 10) return Colors.green;
    if (diff.inHours   < 1)  return Colors.orange;
    return Colors.red;
  }

  // ── Manual refresh ─────────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing       = true;
      _syncStatusLabel = 'Syncing…';
      _syncStatusColor = Colors.blue;
    });

    // Capture the provider before the async gap.
    final finance = context.read<FinanceProvider>();

    // Wire a temporary callback that updates both the screen counter and the
    // main transaction list in FinanceProvider.
    SmsSyncService.instance.onTransaction = (tx) {
      finance.prependSmsTransaction(tx);
      if (mounted) setState(() => _totalTransactions++);
    };

    await SmsSyncService.instance.syncSms();

    // Restore the permanent callback so auto-sync still works after this screen
    // is popped.
    SmsSyncService.instance.onTransaction = finance.prependSmsTransaction;

    // Reload authoritative counts from storage.
    await _loadStatus();

    if (mounted) {
      setState(() => _isSyncing = false);
      _showSnack('Sync complete');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  String get _permLabel {
    switch (_permStatus) {
      case PermissionStatus.granted:            return 'Granted';
      case PermissionStatus.denied:             return 'Denied';
      case PermissionStatus.permanentlyDenied:  return 'Permanently denied';
      case PermissionStatus.restricted:         return 'Restricted';
      case PermissionStatus.limited:            return 'Limited';
      default:                                  return 'Unknown';
    }
  }

  Color get _permColor {
    if (_permStatus == PermissionStatus.granted) return Colors.green;
    if (_permStatus == PermissionStatus.limited)  return Colors.orange;
    return Colors.red;
  }

  IconData get _permIcon {
    if (_permStatus == PermissionStatus.granted) return Icons.check_circle_outline;
    if (_permStatus == PermissionStatus.limited)  return Icons.warning_amber_outlined;
    return Icons.cancel_outlined;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SMS Sync',
          style: TextStyle(
            color: _kNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kNavy),
            tooltip: 'Refresh status',
            onPressed: _isSyncing ? null : _loadStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // ── Hero status card ─────────────────────────────────────────
            _HeroCard(
              isSyncing:   _isSyncing,
              statusLabel: _syncStatusLabel,
              statusColor: _syncStatusColor,
            ),

            const SizedBox(height: 20),

            // ── Info grid ────────────────────────────────────────────────
            _SectionLabel(label: 'STATUS'),
            const SizedBox(height: 10),

            _InfoCard(
              children: [
                _InfoRow(
                  icon: _permIcon,
                  iconColor: _permColor,
                  label: 'SMS Permission',
                  value: _permLabel,
                  valueColor: _permColor,
                ),
                const _Divider(),
                _InfoRow(
                  icon: Icons.access_time_outlined,
                  iconColor: _kNavy,
                  label: 'Last Sync',
                  value: _lastSyncTime != null
                      ? _formatDateTime(_lastSyncTime!)
                      : 'Never',
                ),
                const _Divider(),
                _InfoRow(
                  icon: Icons.receipt_long_outlined,
                  iconColor: _kNavy,
                  label: 'Transactions Found',
                  value: _totalTransactions.toString(),
                ),
                const _Divider(),
                _InfoRow(
                  icon: Icons.sync,
                  iconColor: _syncStatusColor,
                  label: 'Sync Status',
                  value: _syncStatusLabel,
                  valueColor: _syncStatusColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── How it works ─────────────────────────────────────────────
            _SectionLabel(label: 'HOW IT WORKS'),
            const SizedBox(height: 10),

            _InfoCard(
              children: [
                _StepRow(step: '1', text: 'App reads your SMS inbox on open and resume'),
                const _Divider(),
                _StepRow(step: '2', text: 'Only bank & financial messages are processed'),
                const _Divider(),
                _StepRow(step: '3', text: 'Transactions are stored locally — never uploaded'),
                const _Divider(),
                _StepRow(step: '4', text: 'Sync is skipped if run within the last 5 minutes'),
              ],
            ),

            const SizedBox(height: 32),

            // ── Refresh button ────────────────────────────────────────────
            _RefreshButton(
              isSyncing: _isSyncing,
              onPressed: _onRefresh,
            ),

            const SizedBox(height: 16),

            // ── Permission CTA (shown only when not granted) ──────────────
            if (_permStatus != null &&
                _permStatus != PermissionStatus.granted)
              _PermissionBanner(
                isPermanent:
                    _permStatus == PermissionStatus.permanentlyDenied,
                onRequest: () async {
                  if (_permStatus == PermissionStatus.permanentlyDenied) {
                    await openAppSettings();
                  } else {
                    await Permission.sms.request();
                  }
                  await _loadStatus();
                },
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$min';
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final bool   isSyncing;
  final String statusLabel;
  final Color  statusColor;

  const _HeroCard({
    required this.isSyncing,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isSyncing
                ? const SizedBox(
                    key: ValueKey('spinner'),
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Container(
                    key: const ValueKey('icon'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_outlined,
                        color: Colors.white, size: 28),
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SMS Transaction Sync',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSyncing ? Colors.white70 : statusColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            child: Text(isSyncing ? 'Syncing your inbox…' : statusLabel),
          ),
        ],
      ),
    );
  }
}

// ── Refresh button ────────────────────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onPressed;

  const _RefreshButton({required this.isSyncing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kNavy,
          disabledBackgroundColor: _kNavy.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        onPressed: isSyncing ? null : onPressed,
        icon: isSyncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.sync, color: Colors.white),
        label: Text(
          isSyncing ? 'Syncing…' : 'Refresh Sync',
          style: const TextStyle(
              fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Permission banner ─────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final bool isPermanent;
  final VoidCallback onRequest;

  const _PermissionBanner(
      {required this.isPermanent, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPermanent
                  ? 'SMS permission permanently denied. Open Settings to enable it.'
                  : 'SMS permission is required to read transaction messages.',
              style:
                  TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRequest,
            child: Text(
              isPermanent ? 'Settings' : 'Allow',
              style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: valueColor ?? _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step row ──────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final String step;
  final String text;

  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _kNavy,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Thin divider ──────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }
}
