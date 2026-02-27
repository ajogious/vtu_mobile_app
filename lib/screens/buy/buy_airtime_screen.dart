// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/airtime_network_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_purchase_blocker.dart';
import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../services/storage_service.dart';
import '../../models/transaction_model.dart';
import '../../services/notification_service.dart';
import '../../utils/app_formatters.dart';
import 'airtime_success_screen.dart';

class BuyAirtimeScreen extends StatefulWidget {
  const BuyAirtimeScreen({super.key});

  @override
  State<BuyAirtimeScreen> createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedNetwork;
  AirtimeNetwork? _selectedAirtimeNetwork;
  bool _saveBeneficiary = false;
  bool _isProcessing = false;
  bool _loadingNetworks = true;
  List<AirtimeNetwork> _airtimeNetworks = [];

  List<Map<String, String>> _beneficiaries = [];
  List<Transaction> _recentTransactions = [];

  final List<double> _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    _loadRecentTransactions();
    _loadAirtimeNetworks();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAirtimeNetworks() async {
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getAirtimeNetworks();

    if (!mounted) return;

    if (result.success && result.data != null && result.data!.isNotEmpty) {
      setState(() {
        _airtimeNetworks = result.data!;
        _loadingNetworks = false;
      });
    } else {
      // Fallback to basic network list if API fails
      setState(() {
        _airtimeNetworks = [
          const AirtimeNetwork(network: 'MTN', serviceKey: 'MTN_VTU'),
          const AirtimeNetwork(network: 'GLO', serviceKey: 'GLO_VTU'),
          const AirtimeNetwork(network: 'AIRTEL', serviceKey: 'AIRTEL_VTU'),
          const AirtimeNetwork(network: '9MOBILE', serviceKey: '9MOBILE_VTU'),
        ];
        _loadingNetworks = false;
      });
    }
  }

  void _loadBeneficiaries() {
    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();

    if (beneficiaries['airtime'] != null) {
      setState(() {
        _beneficiaries = List<Map<String, String>>.from(
          beneficiaries['airtime'].map((b) => Map<String, String>.from(b)),
        );
      });
    }
  }

  void _loadRecentTransactions() {
    // FIX: use allTransactions (unfiltered) so recent purchases always show
    final transactions = context
        .read<TransactionProvider>()
        .allTransactions
        .where((t) => t.type == TransactionType.airtime)
        .take(5)
        .toList();

    setState(() {
      _recentTransactions = transactions;
    });
  }

  Future<void> _saveBeneficiaryToStorage() async {
    if (!_saveBeneficiary || _phoneController.text.trim().isEmpty) return;

    final phone = _phoneController.text.trim();
    final network = _selectedNetwork ?? '';

    final exists = _beneficiaries.any((b) => b['phone'] == phone);
    if (exists) return;

    _beneficiaries.insert(0, {'phone': phone, 'network': network});

    if (_beneficiaries.length > 10) {
      _beneficiaries = _beneficiaries.sublist(0, 10);
    }

    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();
    beneficiaries['airtime'] = _beneficiaries;
    await storage.saveBeneficiaries(beneficiaries);
  }

  Future<void> _pickContact() async {
    try {
      PermissionStatus status = await Permission.contacts.status;

      if (status.isDenied) {
        status = await Permission.contacts.request();
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;

        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Contact permission is required to pick a phone number. '
              'Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        return;
      }

      if (!status.isGranted) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Contact permission is required to pick a number',
          isError: true,
        );
        return;
      }

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
        withPhoto: false,
      );

      if (fullContact == null) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Could not load contact details',
          isError: true,
        );
        return;
      }

      if (fullContact.phones.isEmpty) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Selected contact has no phone number',
          isError: true,
        );
        return;
      }

      String phone = fullContact.phones.first.number;
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

      if (phone.startsWith('+234')) {
        phone = '0${phone.substring(4)}';
      } else if (phone.startsWith('234')) {
        phone = '0${phone.substring(3)}';
      }

      if (!phone.startsWith('0') && phone.length >= 10) {
        phone = '0$phone';
      }

      if (phone.length > 11) {
        phone = phone.substring(0, 11);
      }

      if (mounted) {
        setState(() {
          _phoneController.text = phone;
        });
        UiHelpers.showSnackBar(context, 'Contact added successfully');
      }
    } on Exception catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to pick contact';
      if (e.toString().contains('PlatformException')) {
        errorMessage = 'Error accessing contacts. Please try again.';
      } else if (e.toString().contains('MissingPluginException')) {
        errorMessage =
            'Contact plugin not properly installed. Please restart the app.';
      }

      UiHelpers.showSnackBar(context, errorMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(
        context,
        'An unexpected error occurred',
        isError: true,
      );
    }
  }

  void _setQuickAmount(double amount) {
    _amountController.text = NumberFormat('#,###').format(amount);
  }

  void _selectBeneficiary(Map<String, String> beneficiary) {
    final networkName = beneficiary['network'] ?? '';
    setState(() {
      _phoneController.text = beneficiary['phone'] ?? '';
      _selectedNetwork = networkName;
      _selectedAirtimeNetwork = _airtimeNetworks
          .where((n) => n.network == networkName)
          .firstOrNull;
    });
  }

  void _selectFromTransaction(Transaction transaction) {
    setState(() {
      _phoneController.text = transaction.beneficiary ?? '';
      _selectedNetwork = transaction.network;
      _selectedAirtimeNetwork = _airtimeNetworks
          .where((n) => n.network == transaction.network)
          .firstOrNull;
      _amountController.text = NumberFormat('#,###').format(transaction.amount);
    });
  }

  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedNetwork == null) {
      UiHelpers.showSnackBar(context, 'Please select a network', isError: true);
      return;
    }

    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final phone = _phoneController.text.trim();
    final airtimeAmount = double.parse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    // How much is deducted from wallet (airtime value minus discount)
    final discountRate = _selectedAirtimeNetwork?.ratePercent ?? 0;
    final discountAmount = airtimeAmount * discountRate;
    final costToUser = airtimeAmount - discountAmount;

    final balance = context.read<WalletProvider>().balance;
    if (balance < costToUser) {
      ErrorHandler.handleInsufficientBalance(context, balance, costToUser);
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
            _buildConfirmRow('Phone Number', phone),
            const Divider(height: 24),
            _buildConfirmRow(
              'Airtime Value',
              '₦${NumberFormat('#,##0.00').format(airtimeAmount)}',
            ),
            if (discountRate > 0) ...[
              _buildConfirmRow(
                'Discount (${(discountRate * 100).toStringAsFixed(0)}%)',
                '- ₦${NumberFormat('#,##0.00').format(discountAmount)}',
                isDiscount: true,
              ),
            ],
            const Divider(height: 16),
            _buildConfirmRow(
              'You Pay',
              '₦${NumberFormat('#,##0.00').format(costToUser)}',
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
      _buyAirtime();
    }
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    bool isBold = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDiscount ? Colors.green[700] : Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: isDiscount ? Colors.green[700] : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyAirtime() async {
    final phone = _phoneController.text.trim();
    final airtimeAmount = double.parse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    final discountRate = _selectedAirtimeNetwork?.ratePercent ?? 0;
    final costToUser = airtimeAmount * (1 - discountRate);

    final serverPinSet = context.read<AuthProvider>().user?.pinSet == true;
    final verifiedPin = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle:
          'Pay ₦${NumberFormat('#,##0').format(costToUser)} for ₦${NumberFormat('#,##0').format(airtimeAmount)} $_selectedNetwork airtime',
      serverPinSet: serverPinSet,
    );

    if (verifiedPin == null) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    if (costToUser >= 10000) {
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

    final result = await authService.api.buyAirtime(
      // FIX: send plain network name (e.g. "MTN"), not serviceKey ("MTN_VTU")
      network: _selectedNetwork!,
      number: phone,
      amount: airtimeAmount,
      pincode: verifiedPin,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.success && result.data != null) {
      await _saveBeneficiaryToStorage();

      final walletProvider = context.read<WalletProvider>();
      final balanceBefore = walletProvider.balance;

      // Deduct only what the user actually paid (discounted cost)
      walletProvider.deductBalance(costToUser);

      final transaction = Transaction(
        id: result.data!['transaction_id'] ?? '',
        type: TransactionType.airtime,
        network: _selectedNetwork!,
        // amount = airtime value received (shown on success screen)
        amount: airtimeAmount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: phone,
        reference: result.data!['transaction_id'] ?? '',
        balanceBefore: balanceBefore,
        balanceAfter: balanceBefore - costToUser,
        metadata: discountRate > 0
            ? {
                'discount_rate': discountRate.toString(),
                'cost_to_user': costToUser.toString(),
              }
            : null,
      );

      context.read<TransactionProvider>().addTransaction(transaction);

      await NotificationService.transactionSuccess(transaction);

      final newBalance = context.read<WalletProvider>().balance;
      if (newBalance < 500) {
        await NotificationService.lowBalance(newBalance);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AirtimeSuccessScreen(transaction: transaction),
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
        appBar: AppBar(title: const Text('Buy Airtime'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing airtime purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Offline banner
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  // Network Selector
                  _loadingNetworks
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : NetworkSelector(
                          selectedNetwork: _selectedNetwork,
                          networks: _airtimeNetworks,
                          onNetworkSelected: (airtimeNetwork) {
                            setState(() {
                              _selectedNetwork = airtimeNetwork.network;
                              _selectedAirtimeNetwork = airtimeNetwork;
                            });
                          },
                        ),
                  const SizedBox(height: 24),

                  // Phone Number with Contact Picker
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _phoneController,
                          labelText: 'Phone Number',
                          hintText: '08012345678',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: Validators.nigerianPhone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickContact,
                        icon: const Icon(Icons.contacts),
                        tooltip: 'Pick from contacts',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
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
                      if (amount == null || amount < 50) {
                        return 'Minimum amount is ₦50';
                      }
                      if (amount > 10000) {
                        return 'Maximum amount is ₦10,000';
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
                        child: Text('₦${NumberFormat('#,##0').format(amount)}'),
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
                  const SizedBox(height: 24),

                  // Buy Button
                  OfflinePurchaseBlocker(
                    serviceName: 'airtime',
                    child: CustomButton(
                      text: 'Buy Airtime',
                      onPressed: networkProvider.isOnline
                          ? _showConfirmationDialog
                          : null,
                      isLoading: _isProcessing,
                    ),
                  ),
                  const SizedBox(height: 32),

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
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _beneficiaries.length,
                        itemBuilder: (context, index) {
                          return _buildBeneficiaryCard(_beneficiaries[index]);
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
                    ..._recentTransactions.map(
                      (transaction) => _buildRecentTransactionCard(transaction),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(Map<String, String> beneficiary) {
    final phone = beneficiary['phone'] ?? '';
    final network = beneficiary['network'] ?? '';

    return GestureDetector(
      onTap: () => _selectBeneficiary(beneficiary),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(height: 6),
            Text(
              phone,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              network,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.phone_android, color: Colors.blue),
        ),
        title: Text(transaction.beneficiary ?? ''),
        subtitle: Text(
          '${transaction.network} • ₦${NumberFormat('#,##0').format(transaction.amount)}',
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
