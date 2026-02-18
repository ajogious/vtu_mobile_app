import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/cached_data_badge.dart';
import '../widgets/custom_button.dart';
import '../../models/virtual_account_model.dart';
import '../../utils/ui_helpers.dart';
import 'kyc_screen.dart';
import 'fund_wallet_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _balanceVisible = true;
  List<VirtualAccount> _virtualAccounts = [];
  bool _isLoadingAccounts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVirtualAccounts();
    });
  }

  Future<void> _loadVirtualAccounts() async {
    if (!mounted) return;

    final user = context.read<AuthProvider>().user;

    if (user == null || !user.kycVerified) {
      return;
    }

    setState(() {
      _isLoadingAccounts = true;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getVirtualAccounts();

    if (mounted) {
      setState(() {
        _isLoadingAccounts = false;
      });

      if (result.success && result.data != null) {
        setState(() {
          _virtualAccounts = result.data!;
        });
      }
    }
  }

  Future<void> _refreshWallet() async {
    final walletProvider = context.read<WalletProvider>();
    await walletProvider.fetchBalance();
    await _loadVirtualAccounts();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    UiHelpers.showSnackBar(context, '$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.user;
    final balance = walletProvider.balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshWallet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Card
              _buildBalanceCard(
                balance,
                walletProvider.isLoading,
                walletProvider.lastUpdated,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Fund Wallet',
                      icon: Icons.add,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FundWalletScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Transactions',
                      icon: Icons.receipt_long,
                      isOutlined: true,
                      onPressed: () {
                        UiHelpers.showSnackBar(
                          context,
                          'Transaction screen - Coming in Day 17',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // KYC Banner or Virtual Accounts
              if (user?.kycVerified != true)
                _buildKycBanner()
              else
                _buildVirtualAccounts(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    double balance,
    bool isLoading,
    DateTime? lastUpdated,
  ) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              IconButton(
                icon: Icon(
                  _balanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _balanceVisible = !_balanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _balanceVisible
                    ? '₦${NumberFormat('#,##0.00').format(balance)}'
                    : '₦****.**',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          // Cached data badge — only shown when balance is visible
          if (_balanceVisible) ...[
            const SizedBox(height: 4),
            CachedDataBadge(cachedAt: lastUpdated, label: 'Balance'),
          ],
        ],
      ),
    );
  }

  Widget _buildKycBanner() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete KYC Verification',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Verify your identity with BVN or NIN to get dedicated virtual bank accounts for instant wallet funding.',
              style: TextStyle(color: Colors.orange[800], fontSize: 14),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Verify Now',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KycScreen()),
                );

                if (result == true && mounted) {
                  await _loadVirtualAccounts();
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualAccounts() {
    if (_isLoadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_virtualAccounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.account_balance, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No Virtual Accounts',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete KYC to get virtual accounts',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Virtual Accounts',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Fund your wallet instantly by transferring to any of these accounts',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ..._virtualAccounts.map((account) => _buildAccountCard(account)),
      ],
    );
  }

  Widget _buildAccountCard(VirtualAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.bankName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.accountName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Number',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.accountNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(
                      account.accountNumber,
                      'Account number',
                    ),
                    tooltip: 'Copy account number',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
