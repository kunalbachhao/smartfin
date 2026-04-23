import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';
import 'sms_sync_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final auth = context.watch<AuthProvider>();
    // Use the authenticated email if available, fall back to the hint text.
    final displayEmail = auth.email ?? provider.loginContent.emailHint;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),

            // Header
            const Text(
              'Profile',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3A57)),
            ),

            const SizedBox(height: 24),

            // Avatar + name card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmartFin User',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayEmail,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Income',
                    value: provider.totalBalanceFormatted,
                    color: Colors.green,
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Expenses',
                    value: provider.totalExpensesFormatted,
                    color: Colors.red,
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _SummaryCard(
              label: 'Net Worth',
              value: provider.netWorthFormatted,
              color: const Color(0xFF1B4F72),
              icon: Icons.account_balance_wallet_outlined,
              wide: true,
            ),

            const SizedBox(height: 24),

            // Settings list
            _SettingsSection(
              title: 'Account',
              items: const [
                _SettingsItem(icon: Icons.person_outline, label: 'Personal Information'),
                _SettingsItem(icon: Icons.lock_outline, label: 'Security & Password'),
                _SettingsItem(icon: Icons.notifications_none, label: 'Notifications'),
              ],
            ),

            const SizedBox(height: 16),

            _SettingsSection(
              title: 'Preferences',
              items: const [
                _SettingsItem(icon: Icons.language, label: 'Language'),
                _SettingsItem(icon: Icons.color_lens_outlined, label: 'Appearance'),
              ],
            ),

            const SizedBox(height: 16),

            // SMS Sync section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DATA',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.sms_outlined, color: Color(0xFF1B3A57)),
                title: const Text('SMS Transaction Sync'),
                subtitle: const Text(
                  'View sync status and refresh manually',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SmsSyncScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _SettingsSection(
              title: 'Support',
              items: const [
                _SettingsItem(icon: Icons.help_outline, label: 'Help & FAQ'),
                _SettingsItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy'),
              ],
            ),

            const SizedBox(height: 24),

            // Sign out
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  // AuthWrapper automatically navigates to WelcomeScreen.
                },
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool wide;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: wide ? 18 : 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: items
                .map((item) => ListTile(
                      leading: Icon(item.icon, color: const Color(0xFF1B3A57)),
                      title: Text(item.label),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {},
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  const _SettingsItem({required this.icon, required this.label});
}
