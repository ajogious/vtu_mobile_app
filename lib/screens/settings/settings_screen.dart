// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';
import 'change_pin_screen.dart';
import '../auth/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _transactionNotifications = true;
  bool _walletAlerts = true;
  bool _referralNotifications = true;
  bool _promotionalMessages = false;
  AutoLockDuration _autoLockDuration = AutoLockDuration.oneMinute;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadSettings() async {
    final storage = StorageService();

    setState(() {
      _biometricEnabled = storage.getBiometricEnabled();
      _transactionNotifications = storage.getNotificationPreference(
        'transactions',
      );
      _walletAlerts = storage.getNotificationPreference('wallet');
      _referralNotifications = storage.getNotificationPreference('referrals');
      _promotionalMessages = storage.getNotificationPreference('promotional');
      _autoLockDuration = context.read<AppLockProvider>().autoLockDuration;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    final storage = StorageService();
    await storage.saveBiometricEnabled(value);

    setState(() {
      _biometricEnabled = value;
    });

    UiHelpers.showSnackBar(
      context,
      value ? 'Biometric enabled' : 'Biometric disabled',
    );
  }

  Future<void> _toggleNotification(String type, bool value) async {
    final storage = StorageService();
    await storage.saveNotificationPreference(type, value);

    setState(() {
      switch (type) {
        case 'transactions':
          _transactionNotifications = value;
          break;
        case 'wallet':
          _walletAlerts = value;
          break;
        case 'referrals':
          _referralNotifications = value;
          break;
        case 'promotional':
          _promotionalMessages = value;
          break;
      }
    });
  }

  void _showAutoLockOptions() {
    final lockProvider = context.read<AppLockProvider>();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Auto-Lock Timer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...AutoLockDuration.values.map((duration) {
              final isSelected = _autoLockDuration == duration;
              return ListTile(
                title: Text(lockProvider.getAutoLockLabel(duration)),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () async {
                  await lockProvider.setAutoLockDuration(duration);
                  setState(() {
                    _autoLockDuration = duration;
                  });
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Switch between light and dark theme'),
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
          const Divider(),

          // Security Section
          _buildSectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your transaction PIN'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePinScreen()),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Use fingerprint or face ID'),
            secondary: const Icon(Icons.fingerprint),
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Auto-Lock Timer'),
            subtitle: Text(
              context.read<AppLockProvider>().getAutoLockLabel(
                _autoLockDuration,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showAutoLockOptions,
          ),
          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Transaction Notifications'),
            subtitle: const Text('Get notified of all transactions'),
            secondary: const Icon(Icons.receipt_long),
            value: _transactionNotifications,
            onChanged: (value) => _toggleNotification('transactions', value),
          ),
          SwitchListTile(
            title: const Text('Wallet Alerts'),
            subtitle: const Text('Low balance and funding alerts'),
            secondary: const Icon(Icons.account_balance_wallet),
            value: _walletAlerts,
            onChanged: (value) => _toggleNotification('wallet', value),
          ),
          SwitchListTile(
            title: const Text('Referral Notifications'),
            subtitle: const Text('Updates on referral earnings'),
            secondary: const Icon(Icons.card_giftcard),
            value: _referralNotifications,
            onChanged: (value) => _toggleNotification('referrals', value),
          ),
          SwitchListTile(
            title: const Text('Promotional Messages'),
            subtitle: const Text('Offers and promotions'),
            secondary: const Icon(Icons.local_offer),
            value: _promotionalMessages,
            onChanged: (value) => _toggleNotification('promotional', value),
          ),
          const Divider(),

          // About Section
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: Text(_appVersion.isEmpty ? 'Loading...' : _appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contact Support'),
            subtitle: const Text('support@vtuapp.com'),
            onTap: () {
              // Open email client or support page
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Call Support'),
            subtitle: const Text('+234 800 000 0000'),
            onTap: () {
              // Open phone dialer
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open terms page
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open privacy policy page
            },
          ),
          const Divider(),

          // Logout
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
