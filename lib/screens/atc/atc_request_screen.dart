import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/atc_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/nigeria_network_validator.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/loading_overlay.dart';
import '../../utils/ui_helpers.dart';

class AtcRequestScreen extends StatefulWidget {
  const AtcRequestScreen({super.key});

  @override
  State<AtcRequestScreen> createState() => _AtcRequestScreenState();
}

class _AtcRequestScreenState extends State<AtcRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();

  ATCNetwork? _selectedATCNetwork;
  bool _acceptTerms = false;
  bool _isProcessing = false;
  String? _networkMismatchWarning;
  String _paymentMethod = 'wallet'; // 'wallet' or 'bank'

  List<ATCNetwork> _atcNetworks = [];
  bool _isLoadingNetworks = true;

  // ── Derived helpers ───────────────────────────────────────────────
  int get _displayRate =>
      _selectedATCNetwork != null ? _selectedATCNetwork!.rate.round() : 0;

  double get _conversionRate => _displayRate / 100;

  double get _airtimeAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  double get _receivableAmount => _airtimeAmount * _conversionRate;

  // ── Lifecycle ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadATCNetworks();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────
  Future<void> _loadATCNetworks() async {
    setState(() => _isLoadingNetworks = true);
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getATCNetworks();
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        // Only show networks that are active (rate > 0 and receivePhone set)
        _atcNetworks = result.data!.where((n) => n.isAvailable).toList();
        _isLoadingNetworks = false;
      });
    } else {
      setState(() => _isLoadingNetworks = false);
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to load networks',
        isError: true,
      );
    }
  }

  // ── Mismatch check ────────────────────────────────────────────────
  void _checkNetworkMismatch() {
    if (_selectedATCNetwork == null ||
        _phoneController.text.trim().length < 11) {
      setState(() => _networkMismatchWarning = null);
      return;
    }
    setState(() {
      _networkMismatchWarning = NigeriaNetworkValidator.getMismatchWarning(
        _phoneController.text.trim(),
        _selectedATCNetwork!.network,
      );
    });
  }

  // ── Contact picker ────────────────────────────────────────────────
  Future<void> _pickContact() async {
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) {
      if  (!mounted) return;
      UiHelpers.showSnackBar(
        context,
        'Contact permission is required',
        isError: true,
      );
      return;
    }
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final full = await FlutterContacts.getContact(contact.id);
        if (full != null && full.phones.isNotEmpty) {
          String phone = full.phones.first.number.replaceAll(
            RegExp(r'[\s\-\(\)]'),
            '',
          );
          if (phone.startsWith('+234'))
            phone = '0${phone.substring(4)}';
          else if (phone.startsWith('234'))
            phone = '0${phone.substring(3)}';
          if (!phone.startsWith('0')) phone = '0$phone';
          if (phone.length > 11) phone = phone.substring(0, 11);
          setState(() => _phoneController.text = phone);
          _checkNetworkMismatch();
        }
      }
    } catch (_) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Failed to pick contact', isError: true);
    }
  }

  // ── Network selector widget ───────────────────────────────────────
  Widget _buildNetworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Network',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _atcNetworks.map((atcNetwork) {
            final isSelected =
                _selectedATCNetwork?.network == atcNetwork.network;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedATCNetwork = atcNetwork;
                  _networkMismatchWarning = null;
                });
                _checkNetworkMismatch();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(
                      atcNetwork.network,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${atcNetwork.rate.toStringAsFixed(0)}% rate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Payment method selector ───────────────────────────────────────
  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _paymentMethodTile('wallet', Icons.account_balance_wallet, 'Wallet')),
            const SizedBox(width: 12),
            Expanded(child: _paymentMethodTile('bank', Icons.account_balance, 'Bank Account')),
          ],
        ),
      ],
    );
  }

  Widget _paymentMethodTile(String value, IconData icon, String label) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey[700], size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ── Bank fields ───────────────────────────────────────────────────
  Widget _buildBankFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        CustomTextField(
          controller: _accountNumberController,
          labelText: 'Account Number',
          hintText: 'Enter your bank account number',
          prefixIcon: Icons.credit_card,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (v) {
            if (_paymentMethod != 'bank') return null;
            if (v == null || v.trim().isEmpty) return 'Please enter account number';
            if (v.trim().length < 10) return 'Account number must be at least 10 digits';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _bankNameController,
          labelText: 'Bank Name',
          hintText: 'e.g. Opay, GTBank, Access',
          prefixIcon: Icons.account_balance,
          validator: (v) {
            if (_paymentMethod != 'bank') return null;
            if (v == null || v.trim().isEmpty) return 'Please enter bank name';
            return null;
          },
        ),
      ],
    );
  }

  // ── Confirmation dialog ───────────────────────────────────────────
  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedATCNetwork == null) {
      UiHelpers.showSnackBar(context, 'Please select a network', isError: true);
      return;
    }
    if (!_acceptTerms) {
      UiHelpers.showSnackBar(
        context,
        'Please accept the terms and conditions',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm ATC Request'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfirmRow('Network', _selectedATCNetwork!.network),
                _buildConfirmRow('Phone Number', _phoneController.text.trim()),
                _buildConfirmRow(
                  'Airtime Amount',
                  'N${NumberFormat('#,##0').format(_airtimeAmount)}',
                ),
                _buildConfirmRow('Conversion Rate', '$_displayRate%'),
                _buildConfirmRow(
                  'Payment Method',
                  _paymentMethod == 'bank' ? 'Bank Account' : 'Wallet',
                ),
                if (_paymentMethod == 'bank') ...[ 
                  _buildConfirmRow('Account Number', _accountNumberController.text.trim()),
                  _buildConfirmRow('Bank Name', _bankNameController.text.trim()),
                ],
                // Show the receive_phone so user already knows where to send
                _buildConfirmRow(
                  'Send Airtime To',
                  _selectedATCNetwork!.receivePhone,
                  highlight: true,
                ),
                const Divider(height: 24),
                _buildConfirmRow(
                  'You Will Receive',
                  'N${NumberFormat('#,##0.00').format(_receivableAmount)}',
                  isBold: true,
                ),
                if (_networkMismatchWarning != null) ...[
                  const SizedBox(height: 12),
                  _buildWarningBox(
                    '$_networkMismatchWarning This may still work if the number is ported.',
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your request will be submitted for admin review. '
                          'Cash will be credited after approval.',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

    if (confirmed == true) _submitRequest();
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    bool isBold = false,
    bool highlight = false,
  }) {
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
                fontWeight: (isBold || highlight)
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: highlight ? Colors.orange[800] : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.orange[800], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────
  Future<void> _submitRequest() async {
    setState(() => _isProcessing = true);
    try {
      final authService = context.read<AuthProvider>().authService;
      final result = await authService.api.submitATCRequest(
        network: _selectedATCNetwork!.network,
        amount: _airtimeAmount,
        number: _phoneController.text.trim(),
        paymentMethod: _paymentMethod,
        accountNumber: _paymentMethod == 'bank' ? _accountNumberController.text.trim() : null,
        bankName: _paymentMethod == 'bank' ? _bankNameController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result.success && result.data != null) {
        _showSuccessDialog(result.data!);
      } else {
        UiHelpers.showSnackBar(
          context,
          result.error ?? 'Request failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      UiHelpers.showSnackBar(
        context,
        'Failed to submit request: $e',
        isError: true,
      );
    }
  }

  // ── Success dialog ────────────────────────────────────────────────
  void _showSuccessDialog(Map<String, dynamic> data) {
    final transactionId = data['transaction_id']?.toString() ?? '';
    final sendTo = data['send_to']?.toString() ??
        (_selectedATCNetwork?.receivePhone ?? '');
    final youGet = (data['you_get'] as num?)?.toDouble() ?? _receivableAmount;
    final rate = (data['rate_percent'] as num?)?.toInt() ?? _displayRate;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
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
                'Request Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (transactionId.isNotEmpty)
                Text(
                  'Ref: $transactionId',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),

              // Send airtime to this number
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_forwarded,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send airtime to:',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sendTo,
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // You will receive
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You will receive:',
                      style: TextStyle(color: Colors.green[800], fontSize: 13),
                    ),
                    Text(
                      'N${NumberFormat('#,##0.00').format(youGet)}',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conversion Rate: $rate%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cash will be credited to your wallet after admin approval.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Airtime to Cash'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Submitting your request...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Convert Airtime to Cash',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Select your network, enter the airtime amount and the phone number '
                          'you\'ll be sending from. You\'ll see exactly where to send the airtime.',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Network Selector
                  if (_isLoadingNetworks)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_atcNetworks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: TextButton.icon(
                          onPressed: _loadATCNetworks,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Failed to load networks. Tap to retry',
                          ),
                        ),
                      ),
                    )
                  else
                    _buildNetworkSelector(),
                  const SizedBox(height: 24),

                  // Payment Method
                  _buildPaymentMethodSelector(),
                  const SizedBox(height: 24),

                  // Bank fields (shown only when bank is selected)
                  if (_paymentMethod == 'bank') _buildBankFields(),
                  if (_paymentMethod == 'bank') const SizedBox(height: 16),

                  // Phone Number + contact picker
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _phoneController,
                          labelText: 'Sender Phone Number',
                          hintText: 'Your phone number',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter phone number';
                            }
                            if (value.trim().length != 11) {
                              return 'Phone number must be exactly 11 digits';
                            }
                            if (!value.trim().startsWith('0')) {
                              return 'Phone number must start with 0';
                            }
                            return null;
                          },
                          onChanged: (value) => _checkNetworkMismatch(),
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

                  // Mismatch warning
                  if (_networkMismatchWarning != null) ...[
                    const SizedBox(height: 6),
                    _buildWarningBox(
                      '$_networkMismatchWarning This may still work if the number is ported.',
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Amount Input
                  CustomTextField(
                    controller: _amountController,
                    labelText: 'Airtime Amount',
                    hintText: 'Enter amount',
                    prefixIcon: Icons.money,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value.trim());
                      if (amount == null || amount < 1000) {
                        return 'Minimum amount is N1,000';
                      }
                      if (amount > 50000) {
                        return 'Maximum amount is N50,000';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 24),

                  // Conversion preview
                  if (_selectedATCNetwork != null && _airtimeAmount > 0) ...[
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
                            'You Will Receive',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'N${NumberFormat('#,##0.00').format(_receivableAmount)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Conversion Rate: $_displayRate%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Terms
                  CheckboxListTile(
                    value: _acceptTerms,
                    onChanged: (value) =>
                        setState(() => _acceptTerms = value ?? false),
                    title: const Text(
                      'I understand the process and accept the terms',
                      style: TextStyle(fontSize: 14),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  CustomButton(
                    text: 'Submit Request',
                    icon: Icons.send,
                    onPressed: _showConfirmationDialog,
                    isLoading: _isProcessing,
                  ),
                  const SizedBox(height: 16),

                  // Important notes
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Important',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '- Minimum conversion amount is N1,000\n'
                          '- Request will be reviewed by admin\n'
                          '- Cash credited after approval\n'
                          '- Processing time: 5–30 minutes',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
