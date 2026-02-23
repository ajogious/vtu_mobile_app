import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_purchase_blocker.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../models/transaction_model.dart';
import '../../services/notification_service.dart';
import 'datacard_success_screen.dart';

class DataCardPlan {
  final String id;
  final String network;
  final String networkType;
  final String plan;
  final String size;
  final String duration;
  final double price;

  DataCardPlan({
    required this.id,
    required this.network,
    required this.networkType,
    required this.plan,
    required this.size,
    required this.duration,
    required this.price,
  });

  factory DataCardPlan.fromJson(Map<String, dynamic> json) {
    return DataCardPlan(
      id: json['id'].toString(),
      network: json['network'] ?? '',
      networkType: json['network_type'] ?? '',
      plan: json['plan'] ?? '',
      size: json['size'] ?? '',
      duration: json['duration'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
    );
  }

  String get displayName => '${plan}${size}';
  String get displayLabel => '$network - ${plan}${size} (${networkType})';
}

class BuyDatacardScreen extends StatefulWidget {
  const BuyDatacardScreen({super.key});

  @override
  State<BuyDatacardScreen> createState() => _BuyDatacardScreenState();
}

class _BuyDatacardScreenState extends State<BuyDatacardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  DataCardPlan? _selectedPlan;
  int _quantity = 1;
  bool _isProcessing = false;
  bool _isLoadingPlans = true;
  List<DataCardPlan> _plans = [];

  double get _pricePerCard => _selectedPlan?.price ?? 0;
  double get _totalAmount => _pricePerCard * _quantity;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getDataCardPlans();

    if (!mounted) return;

    if (result.success && result.data != null) {
      final items = result.data!['items'] as List;
      setState(() {
        _plans = items.map((e) => DataCardPlan.fromJson(e)).toList();
        _isLoadingPlans = false;
      });
    } else {
      setState(() => _isLoadingPlans = false);
      ErrorHandler.handleApiError(
        context,
        result.error ?? 'Failed to load data card plans',
      );
    }
  }

  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlan == null) {
      UiHelpers.showSnackBar(context, 'Please select a plan', isError: true);
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
            _buildConfirmRow('Network', _selectedPlan!.network),
            _buildConfirmRow('Plan', _selectedPlan!.displayName),
            _buildConfirmRow('Type', _selectedPlan!.networkType),
            _buildConfirmRow('Duration', _selectedPlan!.duration),
            _buildConfirmRow('Name on Card', _nameController.text.trim()),
            _buildConfirmRow(
              'Quantity',
              '$_quantity card${_quantity > 1 ? 's' : ''}',
            ),
            _buildConfirmRow(
              'Price per Card',
              '₦${NumberFormat('#,##0').format(_pricePerCard)}',
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
      _buyDatacard();
    }
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyDatacard() async {
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final balance = context.read<WalletProvider>().balance;
    if (balance < _totalAmount) {
      ErrorHandler.handleInsufficientBalance(context, balance, _totalAmount);
      return;
    }

    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle:
          'Authorize purchase of $_quantity ${_selectedPlan!.displayName} data card${_quantity > 1 ? 's' : ''}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

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
    final result = await authService.api.buyDataCard(
      cardId: _selectedPlan!.id,
      quantity: _quantity,
      pincode: '12345',
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (result.success && result.data != null) {
      context.read<WalletProvider>().deductBalance(_totalAmount);

      final transaction = Transaction(
        id: result.data!['transaction_id'],
        type: TransactionType.dataCard,
        network: _selectedPlan!.network,
        amount: _totalAmount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: _nameController.text.trim(),
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + _totalAmount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'plan': _selectedPlan!.displayName,
          'network_type': _selectedPlan!.networkType,
          'duration': _selectedPlan!.duration,
          'quantity': _quantity.toString(),
          'name_on_card': _nameController.text.trim(),
          'pins': result.data!['pins'],
        },
      );

      context.read<TransactionProvider>().addTransaction(transaction);
      await NotificationService.transactionSuccess(transaction);

      final newBalance = context.read<WalletProvider>().balance;
      if (newBalance < 500) {
        await NotificationService.lowBalance(newBalance);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DatacardSuccessScreen(transaction: transaction),
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
        appBar: AppBar(title: const Text('Buy Data Cards'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing data card purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  // Plans list
                  Text(
                    'Select Plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoadingPlans)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_plans.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: TextButton.icon(
                          onPressed: _loadPlans,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Failed to load. Tap to retry'),
                        ),
                      ),
                    )
                  else
                    ..._plans.map((plan) => _buildPlanCard(plan)),

                  const SizedBox(height: 24),

                  // Name on Card — only shown after selecting a plan
                  if (_selectedPlan != null) ...[
                    CustomTextField(
                      controller: _nameController,
                      labelText: 'Name on Card',
                      hintText: 'Enter name to print on card',
                      prefixIcon: Icons.person,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter name';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
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
                                'card${_quantity > 1 ? 's' : ''}',
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
                      'Maximum 50 cards per transaction',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Total Amount
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₦${NumberFormat('#,##0.00').format(_totalAmount)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_quantity card${_quantity > 1 ? 's' : ''} × ₦${NumberFormat('#,##0').format(_pricePerCard)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    OfflinePurchaseBlocker(
                      serviceName: 'data cards',
                      child: CustomButton(
                        text: 'Continue',
                        onPressed: networkProvider.isOnline
                            ? _showConfirmationDialog
                            : null,
                        isLoading: _isProcessing,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(DataCardPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlan = plan;
        _quantity = 1; // reset quantity on plan change
      }),
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
              ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.network} ${plan.displayName}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.networkType,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    plan.duration,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '₦${NumberFormat('#,##0').format(plan.price)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
