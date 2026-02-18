import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../config/app_constants.dart';
import '../../services/storage_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/app_formatters.dart';
import 'electricity_success_screen.dart';

class BuyElectricityScreen extends StatefulWidget {
  const BuyElectricityScreen({super.key});

  @override
  State<BuyElectricityScreen> createState() => _BuyElectricityScreenState();
}

class _BuyElectricityScreenState extends State<BuyElectricityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedDisco;
  String? _selectedMeterType;
  String? _customerName;
  String? _customerAddress;
  bool _saveBeneficiary = false;
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isProcessing = false;

  List<Map<String, String>> _beneficiaries = [];
  List<Transaction> _recentTransactions = [];

  final List<double> _quickAmounts = [1000, 2000, 5000, 10000, 20000];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    _loadRecentTransactions();
  }

  @override
  void dispose() {
    _meterController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _loadBeneficiaries() {
    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();

    if (beneficiaries['electricity'] != null) {
      setState(() {
        _beneficiaries = List<Map<String, String>>.from(
          beneficiaries['electricity'].map((b) => Map<String, String>.from(b)),
        );
      });
    }
  }

  void _loadRecentTransactions() {
    final transactions = context
        .read<TransactionProvider>()
        .transactions
        .where((t) => t.type == TransactionType.electricity)
        .take(5)
        .toList();

    setState(() {
      _recentTransactions = transactions;
    });
  }

  Future<void> _saveBeneficiaryToStorage() async {
    if (!_saveBeneficiary || _meterController.text.trim().isEmpty) return;

    final meter = _meterController.text.trim();
    final disco = _selectedDisco ?? '';
    final meterType = _selectedMeterType ?? '';
    final customerName = _customerName ?? '';

    final exists = _beneficiaries.any((b) => b['meter'] == meter);
    if (exists) return;

    _beneficiaries.insert(0, {
      'meter': meter,
      'disco': disco,
      'meter_type': meterType,
      'customer_name': customerName,
    });

    if (_beneficiaries.length > 10) {
      _beneficiaries = _beneficiaries.sublist(0, 10);
    }

    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();
    beneficiaries['electricity'] = _beneficiaries;
    await storage.saveBeneficiaries(beneficiaries);
  }

  void _setQuickAmount(double amount) {
    _amountController.text = NumberFormat('#,###').format(amount);
  }

  Future<void> _validateMeter() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDisco == null) {
      UiHelpers.showSnackBar(context, 'Please select a DISCO', isError: true);
      return;
    }

    if (_selectedMeterType == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select meter type',
        isError: true,
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _customerName = null;
      _customerAddress = null;
      _isValidated = false;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.validateMeter(
      disco: _selectedDisco!,
      meterType: _selectedMeterType!,
      meterNumber: _meterController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isValidating = false;
    });

    if (result.success && result.data != null) {
      setState(() {
        _customerName = result.data!['customer_name'];
        _customerAddress = result.data!['address'];
        _isValidated = true;
      });

      UiHelpers.showSnackBar(context, 'Meter validated successfully');
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Invalid meter number',
        isError: true,
      );
    }
  }

  void _selectBeneficiary(Map<String, String> beneficiary) {
    setState(() {
      _meterController.text = beneficiary['meter'] ?? '';
      _selectedDisco = beneficiary['disco'];
      _selectedMeterType = beneficiary['meter_type'];
      _customerName = null;
      _customerAddress = null;
      _isValidated = false;
    });

    // Auto-validate
    if (_selectedDisco != null &&
        _selectedMeterType != null &&
        _meterController.text.isNotEmpty) {
      _validateMeter();
    }
  }

  void _selectFromTransaction(Transaction transaction) {
    setState(() {
      _meterController.text = transaction.beneficiary ?? '';
      _selectedDisco = transaction.network;
      _selectedMeterType = transaction.metadata?['meter_type'];
      _customerName = null;
      _customerAddress = null;
      _isValidated = false;
      _amountController.text = NumberFormat('#,###').format(transaction.amount);
    });

    // Auto-validate
    if (_selectedDisco != null &&
        _selectedMeterType != null &&
        _meterController.text.isNotEmpty) {
      _validateMeter();
    }
  }

  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDisco == null) {
      UiHelpers.showSnackBar(context, 'Please select a DISCO', isError: true);
      return;
    }

    if (_selectedMeterType == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select meter type',
        isError: true,
      );
      return;
    }

    if (!_isValidated) {
      UiHelpers.showSnackBar(
        context,
        'Please validate meter number',
        isError: true,
      );
      return;
    }

    final amount = double.parse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('DISCO', _selectedDisco!),
            _buildConfirmRow('Meter Type', _selectedMeterType!),
            _buildConfirmRow('Meter Number', _meterController.text.trim()),
            _buildConfirmRow('Customer', _customerName ?? ''),
            if (_customerAddress != null)
              _buildConfirmRow('Address', _customerAddress!),
            const Divider(height: 24),
            _buildConfirmRow(
              'Amount',
              '₦${NumberFormat('#,##0.00').format(amount)}',
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
      _buyElectricity();
    }
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
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

  Future<void> _buyElectricity() async {
    // Check internet connection
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final meter = _meterController.text.trim();
    final amount = double.parse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    // Check balance
    final balance = context.read<WalletProvider>().balance;
    if (balance < amount) {
      ErrorHandler.handleInsufficientBalance(context, balance, amount);
      return;
    }

    // Verify PIN
    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle: 'Authorize payment of ₦${NumberFormat('#,##0').format(amount)}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    // Re-authentication for large amounts
    if (amount >= 10000) {
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

    setState(() {
      _isProcessing = true;
    });

    // Call API
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.buyElectricity(
      disco: _selectedDisco!,
      meter: meter,
      amount: amount,
      pincode: '12345',
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result.success && result.data != null) {
      // Save beneficiary if checked
      await _saveBeneficiaryToStorage();

      // Update balance
      final walletProvider = context.read<WalletProvider>();
      walletProvider.deductBalance(amount);

      // Create transaction
      final transaction = Transaction(
        id: result.data!['transaction_id'],
        type: TransactionType.electricity,
        network: _selectedDisco!,
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: meter,
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + amount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'customer_name': _customerName ?? '',
          'address': _customerAddress ?? '',
          'meter_type': _selectedMeterType!,
          'token': result.data!['token'],
          'units': result.data!['units'].toString(),
        },
      );

      // Add to history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ElectricitySuccessScreen(transaction: transaction),
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
        appBar: AppBar(title: const Text('Buy Electricity'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing electricity purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Network offline warning
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  // DISCO Selector
                  Text(
                    'Select DISCO',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.discos.map((disco) {
                      final isSelected = _selectedDisco == disco;
                      return ChoiceChip(
                        label: Text(disco),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDisco = disco;
                              _customerName = null;
                              _customerAddress = null;
                              _isValidated = false;
                            });
                          }
                        },
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Meter Type Selector
                  Text(
                    'Meter Type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMeterTypeCard('Prepaid')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMeterTypeCard('Postpaid')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Meter Number
                  CustomTextField(
                    controller: _meterController,
                    labelText: 'Meter Number',
                    hintText: 'Enter meter number',
                    prefixIcon: Icons.electric_meter,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter meter number';
                      }
                      if (value.trim().length < 10) {
                        return 'Meter number must be at least 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Validate Button
                  CustomButton(
                    text: _isValidated ? 'Validated ✓' : 'Validate Meter',
                    icon: _isValidated
                        ? Icons.check_circle
                        : Icons.verified_user,
                    onPressed: _isValidated ? null : _validateMeter,
                    isLoading: _isValidating,
                    backgroundColor: _isValidated ? Colors.green : null,
                  ),
                  const SizedBox(height: 16),

                  // Customer Details (after validation)
                  if (_customerName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.green[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Customer Name',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _customerName!,
                                      style: TextStyle(
                                        color: Colors.green[900],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_customerAddress != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Address',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _customerAddress!,
                                        style: TextStyle(
                                          color: Colors.green[900],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Amount Input
                  if (_isValidated) ...[
                    CustomTextField(
                      controller: _amountController,
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixIcon: Icons.money,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(
                          value.replaceAll(',', '').trim(),
                        );
                        if (amount == null || amount < 1000) {
                          return 'Minimum amount is ₦1,000';
                        }
                        if (amount > 50000) {
                          return 'Maximum amount is ₦50,000';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quick Amount Buttons
                    Text(
                      'Quick Select',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickAmounts.map((amount) {
                        return OutlinedButton(
                          onPressed: () => _setQuickAmount(amount),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            '₦${NumberFormat('#,##0').format(amount)}',
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Save Beneficiary
                    CheckboxListTile(
                      value: _saveBeneficiary,
                      onChanged: (value) {
                        setState(() {
                          _saveBeneficiary = value ?? false;
                        });
                      },
                      title: const Text('Save as beneficiary'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),

                    // Buy Button
                    CustomButton(
                      text: 'Continue',
                      onPressed: networkProvider.isOnline
                          ? _showConfirmationDialog
                          : null,
                      isLoading: _isProcessing,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Beneficiaries
                  if (_beneficiaries.isNotEmpty) ...[
                    Text(
                      'Beneficiaries',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _beneficiaries.length,
                        itemBuilder: (context, index) {
                          final beneficiary = _beneficiaries[index];
                          return _buildBeneficiaryCard(beneficiary);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recent Transactions
                  if (_recentTransactions.isNotEmpty) ...[
                    Text(
                      'Recent Purchases',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._recentTransactions.map((transaction) {
                      return _buildRecentTransactionCard(transaction);
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeterTypeCard(String type) {
    final isSelected = _selectedMeterType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMeterType = type;
          _customerName = null;
          _customerAddress = null;
          _isValidated = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              type == 'Prepaid' ? Icons.bolt : Icons.receipt_long,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(Map<String, String> beneficiary) {
    final meter = beneficiary['meter'] ?? '';
    final disco = beneficiary['disco'] ?? '';
    final meterType = beneficiary['meter_type'] ?? '';
    final customerName = beneficiary['customer_name'] ?? '';

    return GestureDetector(
      onTap: () => _selectBeneficiary(beneficiary),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(height: 6),
            Text(
              customerName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              meter,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '$disco • $meterType',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionCard(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.bolt, color: Colors.orange),
        ),
        title: Text(transaction.metadata?['customer_name'] ?? ''),
        subtitle: Text(
          '${transaction.network} • ${transaction.metadata?['meter_type']} • ₦${NumberFormat('#,##0').format(transaction.amount)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward, size: 20),
          onPressed: () => _selectFromTransaction(transaction),
        ),
      ),
    );
  }
}
