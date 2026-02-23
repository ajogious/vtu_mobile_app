import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/exam_type_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_purchase_blocker.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../models/transaction_model.dart';
import '../../services/notification_service.dart';
import 'exam_pin_success_screen.dart';

class BuyExamPinScreen extends StatefulWidget {
  const BuyExamPinScreen({super.key});

  @override
  State<BuyExamPinScreen> createState() => _BuyExamPinScreenState();
}

class _BuyExamPinScreenState extends State<BuyExamPinScreen> {
  final _formKey = GlobalKey<FormState>();

  ExamType? _selectedExamType;
  int _quantity = 1;
  bool _isProcessing = false;
  bool _isLoadingPlans = true;
  List<ExamType> _examPlans = [];

  double get _pricePerPin => _selectedExamType?.price ?? 0;
  double get _totalAmount => _pricePerPin * _quantity;

  @override
  void initState() {
    super.initState();
    _loadExamPlans();
  }

  Future<void> _loadExamPlans() async {
    setState(() => _isLoadingPlans = true);

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getExamTypes();

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _examPlans = result.data!;
        _isLoadingPlans = false;
      });
    } else {
      setState(() => _isLoadingPlans = false);
      ErrorHandler.handleApiError(
        context,
        result.error ?? 'Failed to load exam plans',
      );
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_selectedExamType == null) {
      UiHelpers.showSnackBar(context, 'Please select exam type', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('Exam Type', _selectedExamType!.examType),
            _buildConfirmRow(
              'Quantity',
              '$_quantity pin${_quantity > 1 ? 's' : ''}',
            ),
            _buildConfirmRow(
              'Price per Pin',
              '₦${NumberFormat('#,##0').format(_pricePerPin)}',
            ),
            const Divider(height: 24),
            _buildConfirmRow(
              'Total Amount',
              '₦${NumberFormat('#,##0.00').format(_totalAmount)}',
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _buyExamPin();
    }
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyExamPin() async {
    // Check internet connection
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    // Check balance
    final balance = context.read<WalletProvider>().balance;
    if (balance < _totalAmount) {
      ErrorHandler.handleInsufficientBalance(context, balance, _totalAmount);
      return;
    }

    // Verify PIN
    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle:
          'Authorize purchase of $_quantity ${_selectedExamType!.examType} pin${_quantity > 1 ? 's' : ''}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    // Re-authentication for large amounts
    if (_totalAmount >= 10000) {
      final reAuthenticated = await requireReAuthentication(
        context,
        action: 'authorize this large transaction',
      );

      if (!reAuthenticated) {
        UiHelpers.showSnackBar(
          context,
          'Re-authentication failed',
          isError: true,
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.buyExamPin(
      examType: _selectedExamType!.examType,
      quantity: _quantity,
      pincode: '12345',
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (result.success && result.data != null) {
      // Update balance
      context.read<WalletProvider>().deductBalance(_totalAmount);

      // Create transaction
      final transaction = Transaction(
        id: result.data!['transaction_id'],
        type: TransactionType.examPin,
        network: _selectedExamType!.examType,
        amount: _totalAmount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: '$_quantity pin${_quantity > 1 ? 's' : ''}',
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + _totalAmount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'quantity': _quantity.toString(),
          'pins': result.data!['pins'],
        },
      );

      // Add to history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Fire notification
      await NotificationService.transactionSuccess(transaction);

      // Check low balance
      final newBalance = context.read<WalletProvider>().balance;
      if (newBalance < 500) {
        await NotificationService.lowBalance(newBalance);
      }

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExamPinSuccessScreen(transaction: transaction),
        ),
      );
    } else {
      ErrorHandler.handleApiError(context, result.error ?? 'Purchase failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkProvider = context.watch<NetworkProvider>();

    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Exam Pins'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing exam pin purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  // Exam Type Selector
                  Text(
                    'Select Exam Type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Loading / error / list states
                  if (_isLoadingPlans)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_examPlans.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: TextButton.icon(
                          onPressed: _loadExamPlans,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Failed to load. Tap to retry'),
                        ),
                      ),
                    )
                  else
                    ..._examPlans.map((plan) => _buildExamTypeCard(plan)),

                  const SizedBox(height: 24),

                  // Price Info — only shown when a plan is selected
                  if (_selectedExamType != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Price: ₦${NumberFormat('#,##0').format(_pricePerPin)} per pin',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Quantity Selector
                  Text(
                    'Quantity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 32,
                        ),
                        Column(
                          children: [
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'pin${_quantity > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _quantity < 50
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maximum 50 pins per transaction',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Total Amount Display
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(_totalAmount)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedExamType != null
                              ? '$_quantity pin${_quantity > 1 ? 's' : ''} × ₦${NumberFormat('#,##0').format(_pricePerPin)}'
                              : 'Select an exam type above',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Buy Button
                  OfflinePurchaseBlocker(
                    serviceName: 'exam pins',
                    child: CustomButton(
                      text: 'Continue',
                      onPressed:
                          networkProvider.isOnline && _selectedExamType != null
                          ? _showConfirmationDialog
                          : null,
                      isLoading: _isProcessing,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamTypeCard(ExamType plan) {
    final isSelected = _selectedExamType?.examType == plan.examType;

    return GestureDetector(
      onTap: () => setState(() => _selectedExamType = plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: plan.examType,
              groupValue: _selectedExamType?.examType,
              onChanged: (_) => setState(() => _selectedExamType = plan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.examType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  Text(
                    '₦${NumberFormat('#,##0').format(plan.price)} per pin',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.school,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
