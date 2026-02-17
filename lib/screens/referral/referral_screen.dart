import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/referral_provider.dart';
import '../../utils/ui_helpers.dart';
import '../widgets/custom_button.dart';
import 'withdraw_earnings_screen.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReferralData();
    });
  }

  Future<void> _loadReferralData() async {
    await context.read<ReferralProvider>().fetchReferralData();
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    UiHelpers.showSnackBar(context, 'Referral code copied to clipboard');
  }

  void _shareReferralCode(String code) {
    final message =
        '''
🎉 Join VTU App and get amazing rewards!

Use my referral code: $code

✅ Buy airtime & data at best rates
✅ Pay bills instantly
✅ Earn while you refer

Download now and start earning!'''
            .trim();

    Share.share(message);
  }

  void _shareViaWhatsApp(String code) {
    final message =
        '''
🎉 Join VTU App and get amazing rewards!

Use my referral code: *$code*

✅ Buy airtime & data at best rates
✅ Pay bills instantly
✅ Earn while you refer

Download now and start earning!'''
            .trim();

    Share.share(message);
  }

  void _shareViaSMS(String code) {
    Share.share('Join VTU App with my referral code: $code');
  }

  void _shareViaEmail(String code) {
    final message =
        '''
Join VTU App and get amazing rewards!

Use my referral code: $code

✅ Buy airtime & data at best rates
✅ Pay bills instantly
✅ Earn while you refer

Download now and start earning!'''
            .trim();

    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final referralCode = user?.referralCode ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Referrals'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadReferralData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Referral Code Card ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your Referral Code',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),

                    // FIX: use full-width column layout instead of a Row
                    // that can overflow on small screens
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Referral code — scales down if too wide
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              referralCode,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Copy button below the code — full width, never overflows
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _copyReferralCode(referralCode),
                              icon: Icon(
                                Icons.copy,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              label: Text(
                                'Copy Code',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Share your code and earn ₦100 for each referral!',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Share Buttons ───────────────────────────────────────────
              const Text(
                'Share Via',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildShareButton(
                      icon: Icons.share,
                      label: 'Share',
                      color: Colors.blue,
                      onTap: () => _shareReferralCode(referralCode),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildShareButton(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: Colors.green,
                      onTap: () => _shareViaWhatsApp(referralCode),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildShareButton(
                      icon: Icons.sms,
                      label: 'SMS',
                      color: Colors.orange,
                      onTap: () => _shareViaSMS(referralCode),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildShareButton(
                      icon: Icons.email,
                      label: 'Email',
                      color: Colors.red,
                      onTap: () => _shareViaEmail(referralCode),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Earnings Summary ────────────────────────────────────────
              Consumer<ReferralProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Earnings Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildEarningsCard(
                        'Total Earnings',
                        provider.totalEarnings,
                        Colors.green,
                        Icons.account_balance_wallet,
                      ),
                      const SizedBox(height: 12),

                      _buildEarningsCard(
                        'Available Balance',
                        provider.availableBalance,
                        Colors.blue,
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 12),

                      // Total Referrals
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.group,
                                  color: Colors.purple,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Referrals',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${provider.totalReferrals}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Withdraw Button
                      CustomButton(
                        text: 'Withdraw Earnings',
                        icon: Icons.south_west,
                        onPressed: provider.availableBalance >= 500
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WithdrawEarningsScreen(),
                                  ),
                                );
                              }
                            : null,
                      ),
                      if (provider.availableBalance < 500) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Minimum withdrawal amount is ₦500',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Earnings History
                      if (provider.earnings.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Earnings History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: _showDateFilter,
                              child: const Text('Filter'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...provider.filteredEarnings.map(
                          (earning) => _buildEarningItem(earning),
                        ),
                      ],

                      // Empty State
                      if (provider.earnings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No earnings yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start referring friends to earn rewards!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildEarningsCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  // FittedBox prevents long amounts from overflowing
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₦${NumberFormat('#,##0.00').format(amount)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem(Map<String, dynamic> earning) {
    final amount = earning['amount'] as double;
    final source = earning['source'] as String;
    final date = earning['date'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.add, color: Colors.green),
        ),
        title: Text(
          source,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy • hh:mm a').format(date),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '+₦${NumberFormat('#,##0.00').format(amount)}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showDateFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter by Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Time'),
              onTap: () {
                context.read<ReferralProvider>().filterByDateRange(null, null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Last 7 Days'),
              onTap: () {
                final now = DateTime.now();
                context.read<ReferralProvider>().filterByDateRange(
                  now.subtract(const Duration(days: 6)),
                  now,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Last 30 Days'),
              onTap: () {
                final now = DateTime.now();
                context.read<ReferralProvider>().filterByDateRange(
                  now.subtract(const Duration(days: 29)),
                  now,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('This Month'),
              onTap: () {
                final now = DateTime.now();
                context.read<ReferralProvider>().filterByDateRange(
                  DateTime(now.year, now.month, 1),
                  now,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
