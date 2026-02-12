import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../../utils/ui_helpers.dart';
import '../../config/app_constants.dart';
import '../../models/virtual_account_model.dart';
import '../../models/transaction_model.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  List<VirtualAccount> _virtualAccounts = [];
  bool _isLoadingAccounts = false;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadVirtualAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadVirtualAccounts() async {
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

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    UiHelpers.showSnackBar(context, '$label copied to clipboard');
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter amount';
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Please enter a valid amount';
    }

    if (amount < AppConstants.minFundingAmount) {
      return 'Minimum amount is ₦${NumberFormat('#,##0').format(AppConstants.minFundingAmount)}';
    }

    if (amount > AppConstants.maxFundingAmount) {
      return 'Maximum amount is ₦${NumberFormat('#,##0').format(AppConstants.maxFundingAmount)}';
    }

    return null;
  }

  Future<void> _fundViaCard() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());

    setState(() {
      _isProcessingPayment = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isProcessingPayment = false;
    });

    // Show mock success dialog
    final confirmed = await _showPaymentSuccessDialog(amount);

    if (confirmed == true && mounted) {
      // Update wallet balance
      final walletProvider = context.read<WalletProvider>();
      walletProvider.addBalance(amount);

      // Create transaction
      final transaction = Transaction(
        id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.walletFunding,
        network: 'Paystack',
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: 'Wallet',
        reference: 'PAY${DateTime.now().millisecondsSinceEpoch}',
        balanceBefore: walletProvider.balance - amount,
        balanceAfter: walletProvider.balance,
        metadata: {'payment_method': 'card', 'gateway': 'paystack'},
      );

      // Add to transaction history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Show success message
      UiHelpers.showSnackBar(
        context,
        'Wallet funded successfully with ₦${NumberFormat('#,##0.00').format(amount)}',
      );

      // Go back to previous screen
      Navigator.pop(context);
    }
  }

  Future<bool?> _showPaymentSuccessDialog(double amount) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '₦${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'has been added to your wallet',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isKycVerified = user?.kycVerified ?? false;

    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Fund Wallet'), centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'How much do you want to fund?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Amount Input
                CustomTextField(
                  controller: _amountController,
                  labelText: 'Amount',
                  hintText: 'Enter amount',
                  prefixIcon: Icons.money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateAmount,
                ),
                const SizedBox(height: 16),

                // Min/Max info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Min: ₦${NumberFormat('#,##0').format(AppConstants.minFundingAmount)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'Max: ₦${NumberFormat('#,##0').format(AppConstants.maxFundingAmount)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Amount Buttons
                Text(
                  'Quick Amounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppConstants.quickAirtimeAmounts
                      .where((amount) => amount >= 500)
                      .map((amount) => _buildQuickAmountButton(amount))
                      .toList(),
                ),
                const SizedBox(height: 32),

                // Virtual Accounts Section (if KYC verified)
                if (isKycVerified) ...[
                  _buildVirtualAccountsSection(),
                  const SizedBox(height: 32),

                  // OR Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],

                // Fund via Card Button
                CustomButton(
                  text: 'Fund via Card',
                  icon: Icons.credit_card,
                  onPressed: _fundViaCard,
                  isLoading: _isProcessingPayment,
                ),
                const SizedBox(height: 16),

                // Payment info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Secure payment powered by Paystack • Instant funding',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // KYC prompt (if not verified)
                if (!isKycVerified) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance,
                              color: Colors.orange[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Get Virtual Bank Accounts',
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
                          'Complete KYC verification to get dedicated virtual accounts for instant wallet funding via bank transfer.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Navigate to KYC (will implement later)
                              UiHelpers.showSnackBar(
                                context,
                                'Navigate to KYC screen',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange[700],
                              side: BorderSide(color: Colors.orange[700]!),
                            ),
                            child: const Text('Verify KYC'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount) {
    return OutlinedButton(
      onPressed: () => _setQuickAmount(amount),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        '₦${NumberFormat('#,##0').format(amount)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVirtualAccountsSection() {
    if (_isLoadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer to Virtual Account',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Transfer any amount to any of these accounts to fund your wallet instantly',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                    size: 20,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        account.accountName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      account.accountNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
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
