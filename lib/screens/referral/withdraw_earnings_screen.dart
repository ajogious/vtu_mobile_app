import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/referral_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../../utils/ui_helpers.dart';
import '../../models/transaction_model.dart';
import '../../services/notification_service.dart';

class WithdrawEarningsScreen extends StatefulWidget {
  const WithdrawEarningsScreen({super.key});

  @override
  State<WithdrawEarningsScreen> createState() => _WithdrawEarningsScreenState();
}

class _WithdrawEarningsScreenState extends State<WithdrawEarningsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setMaxAmount() {
    final availableBalance = context.read<ReferralProvider>().availableBalance;
    _amountController.text = availableBalance.toStringAsFixed(0);
  }

  Future<void> _withdraw() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final availableBalance = context.read<ReferralProvider>().availableBalance;

    // Check balance
    if (amount > availableBalance) {
      UiHelpers.showSnackBar(
        context,
        'Amount exceeds available balance',
        isError: true,
      );
      return;
    }

    // Verify PIN
    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Confirm Withdrawal',
      subtitle:
          'Enter PIN to withdraw ₦${NumberFormat('#,##0').format(amount)}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Withdrawal cancelled', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Process withdrawal
    final referralProvider = context.read<ReferralProvider>();
    final success = await referralProvider.withdrawEarnings(amount);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      // Add to wallet
      final walletProvider = context.read<WalletProvider>();
      walletProvider.addBalance(amount);

      // Create transaction
      final transaction = Transaction(
        id: 'REF${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.referralBonus,
        network: 'Referral Withdrawal',
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: 'Wallet',
        reference: 'REFWD${DateTime.now().millisecondsSinceEpoch}',
        balanceBefore: walletProvider.balance - amount,
        balanceAfter: walletProvider.balance,
        metadata: {'type': 'withdrawal', 'source': 'referral_earnings'},
      );

      context.read<TransactionProvider>().addTransaction(transaction);

      // Fire notification
      await NotificationService.walletCredited(amount, 'Referral Earnings');

      // Show success
      if (!mounted) return;

      UiHelpers.showSnackBar(
        context,
        '₦${NumberFormat('#,##0.00').format(amount)} transferred to your wallet',
      );

      Navigator.pop(context);
    } else {
      UiHelpers.showSnackBar(
        context,
        'Withdrawal failed. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Withdraw Earnings'),
          centerTitle: true,
        ),
        body: Consumer<ReferralProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Available Balance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.green, Colors.green.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₦${NumberFormat('#,##0.00').format(provider.availableBalance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Amount Input
                    CustomTextField(
                      controller: _amountController,
                      labelText: 'Amount to Withdraw',
                      hintText: 'Enter amount',
                      prefixIcon: Icons.money,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null) {
                          return 'Please enter a valid amount';
                        }
                        if (amount < 500) {
                          return 'Minimum withdrawal is ₦500';
                        }
                        if (amount > provider.availableBalance) {
                          return 'Amount exceeds available balance';
                        }
                        return null;
                      },
                      suffixIcon: TextButton(
                        onPressed: _setMaxAmount,
                        child: const Text('MAX'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Withdrawal Info',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Minimum withdrawal: ₦500\n'
                                  '• Funds transferred instantly to wallet\n'
                                  '• No withdrawal fees',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Withdraw Button
                    CustomButton(
                      text: 'Withdraw to Wallet',
                      icon: Icons.south_west,
                      onPressed: _withdraw,
                      isLoading: _isProcessing,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
