import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../../utils/ui_helpers.dart';
import '../../models/transaction_model.dart';
import 'datacard_success_screen.dart';

class BuyDatacardScreen extends StatefulWidget {
  const BuyDatacardScreen({super.key});

  @override
  State<BuyDatacardScreen> createState() => _BuyDatacardScreenState();
}

class _BuyDatacardScreenState extends State<BuyDatacardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedNetwork;
  String? _selectedDenomination;
  int _quantity = 1;
  bool _isProcessing = false;

  final Map<String, Map<String, double>> _denominationPrices = {
    'MTN': {'1GB': 500, '2GB': 950, '5GB': 2300},
    'GLO': {'1GB': 450, '2GB': 850, '5GB': 2100},
    'AIRTEL': {'1GB': 480, '2GB': 900, '5GB': 2200},
    '9MOBILE': {'1GB': 470, '2GB': 880, '5GB': 2150},
  };

  List<String> get _availableDenominations {
    if (_selectedNetwork == null) return [];
    return _denominationPrices[_selectedNetwork]!.keys.toList();
  }

  double get _pricePerCard {
    if (_selectedNetwork == null || _selectedDenomination == null) return 0;
    return _denominationPrices[_selectedNetwork]![_selectedDenomination]!;
  }

  double get _totalAmount => _pricePerCard * _quantity;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNetworkSelected(String network) {
    setState(() {
      _selectedNetwork = network;
      _selectedDenomination = null;
    });
  }

  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedNetwork == null) {
      UiHelpers.showSnackBar(context, 'Please select a network', isError: true);
      return;
    }

    if (_selectedDenomination == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select denomination',
        isError: true,
      );
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
            _buildConfirmRow('Network', _selectedNetwork!),
            _buildConfirmRow('Denomination', _selectedDenomination!),
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
    // Check internet connection
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      UiHelpers.showSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }

    // Check balance
    final balance = context.read<WalletProvider>().balance;
    if (balance < _totalAmount) {
      UiHelpers.showSnackBar(
        context,
        'Insufficient balance. Please fund your wallet.',
        isError: true,
      );
      return;
    }

    // Verify PIN
    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle:
          'Authorize purchase of $_quantity $_selectedNetwork $_selectedDenomination data card${_quantity > 1 ? 's' : ''}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Call API
    final authService = context.read<AuthProvider>().authService;
    final cardId = '${_selectedNetwork!}_${_selectedDenomination!}';
    final result = await authService.api.buyDataCard(
      cardId: cardId,
      quantity: _quantity,
      pincode: '12345',
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result.success && result.data != null) {
      // Update balance
      final walletProvider = context.read<WalletProvider>();
      walletProvider.deductBalance(_totalAmount);

      // Create transaction
      final transaction = Transaction(
        id: result.data!['transaction_id'],
        type: TransactionType.dataCard,
        network: _selectedNetwork!,
        amount: _totalAmount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: _nameController.text.trim(),
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + _totalAmount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'denomination': _selectedDenomination!,
          'quantity': _quantity.toString(),
          'name_on_card': _nameController.text.trim(),
          'pins': result.data!['pins'], // List of {serial, pin}
        },
      );

      // Add to history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DatacardSuccessScreen(transaction: transaction),
        ),
      );
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Purchase failed',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkProvider = context.watch<NetworkProvider>();

    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Data Cards'), centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Network offline warning
                if (!networkProvider.isOnline)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No internet connection. Purchase disabled.',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Network Selector
                NetworkSelector(
                  selectedNetwork: _selectedNetwork,
                  onNetworkSelected: _onNetworkSelected,
                ),
                const SizedBox(height: 24),

                // Denomination Selector
                if (_selectedNetwork != null) ...[
                  Text(
                    'Select Denomination',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._availableDenominations.map((denomination) {
                    return _buildDenominationCard(denomination);
                  }),
                  const SizedBox(height: 24),
                ],

                // Name on Card
                if (_selectedDenomination != null) ...[
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
                              ? () {
                                  setState(() {
                                    _quantity--;
                                  });
                                }
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
                              ? () {
                                  setState(() {
                                    _quantity++;
                                  });
                                }
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

                  // Total Amount Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withValues(alpha: 0.8),
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

                  // Buy Button
                  CustomButton(
                    text: 'Continue',
                    onPressed: networkProvider.isOnline
                        ? _showConfirmationDialog
                        : null,
                    isLoading: _isProcessing,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDenominationCard(String denomination) {
    final isSelected = _selectedDenomination == denomination;
    final price = _denominationPrices[_selectedNetwork]![denomination]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDenomination = denomination;
        });
      },
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
                    denomination,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_selectedNetwork Data Card',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '₦${NumberFormat('#,##0').format(price)}',
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
