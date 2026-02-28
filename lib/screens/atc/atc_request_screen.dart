import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../models/airtime_network_model.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/loading_overlay.dart';
import '../../utils/ui_helpers.dart';

class NigeriaNetworkValidator {
  static const Map<String, List<String>> _networkPrefixes = {
    'MTN': [
      '0703',
      '0706',
      '0803',
      '0806',
      '0810',
      '0813',
      '0814',
      '0816',
      '0903',
      '0906',
      '0913',
      '0916',
      '0704',
      '07025',
      '07026',
    ],
    'GLO': ['0705', '0805', '0807', '0811', '0815', '0905', '0915'],
    'AIRTEL': [
      '0701',
      '0708',
      '0802',
      '0808',
      '0812',
      '0901',
      '0902',
      '0904',
      '0907',
      '0912',
    ],
    '9MOBILE': ['0809', '0817', '0818', '0908', '0909'],
    'NTEL': ['0804'],
    'SMILE': ['0702'],
    'STARCOMMS': ['07028', '07029', '0819'],
    'MULTILINKS': ['07027', '0709'],
  };

  static String? getNetworkForNumber(String phone) {
    final normalized = _normalize(phone);
    if (normalized == null) return null;
    final prefix = normalized.substring(0, 4);
    for (final entry in _networkPrefixes.entries) {
      if (entry.value.contains(prefix)) return entry.key;
    }
    return null;
  }

  static String? getMismatchWarning(String phone, String selectedNetwork) {
    final normalized = _normalize(phone);
    if (normalized == null) return null;
    final detectedNetwork = getNetworkForNumber(normalized);
    if (detectedNetwork == null) return null;
    if (detectedNetwork != selectedNetwork.toUpperCase()) {
      return '$normalized looks like a $detectedNetwork number, '
          'but you selected $selectedNetwork.';
    }
    return null;
  }

  static String? _normalize(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (cleaned.startsWith('+234'))
      cleaned = '0${cleaned.substring(4)}';
    else if (cleaned.startsWith('234'))
      cleaned = '0${cleaned.substring(3)}';
    if (cleaned.length != 11 || !cleaned.startsWith('0')) return null;
    return cleaned;
  }

  static List<String>? getPrefixesForNetwork(String network) {
    return _networkPrefixes[network.toUpperCase()];
  }
}

class AtcRequestScreen extends StatefulWidget {
  const AtcRequestScreen({super.key});

  @override
  State<AtcRequestScreen> createState() => _AtcRequestScreenState();
}

class _AtcRequestScreenState extends State<AtcRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedNetwork;
  bool _acceptTerms = false;
  bool _isProcessing = false;
  int? _apiRate;
  String? _networkMismatchWarning;

  List<AirtimeNetwork> _networks = [];
  bool _isLoadingNetworks = true;

  final Map<String, int> _estimatedRates = {
    'MTN': 90,
    'GLO': 88,
    'AIRTEL': 89,
    '9MOBILE': 87,
  };

  int get _displayRate => _apiRate ?? (_estimatedRates[_selectedNetwork] ?? 85);

  double get _conversionRate => _displayRate / 100;

  double get _airtimeAmount {
    final amount = double.tryParse(_amountController.text.trim());
    return amount ?? 0;
  }

  double get _receivableAmount => _airtimeAmount * _conversionRate;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworks() async {
    setState(() => _isLoadingNetworks = true);
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getAirtimeNetworks();
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _networks = result.data!;
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

  void _checkNetworkMismatch() {
    if (_selectedNetwork == null || _phoneController.text.trim().isEmpty) {
      setState(() => _networkMismatchWarning = null);
      return;
    }
    if (_phoneController.text.trim().length < 11) {
      setState(() => _networkMismatchWarning = null);
      return;
    }
    setState(() {
      _networkMismatchWarning = NigeriaNetworkValidator.getMismatchWarning(
        _phoneController.text.trim(),
        _selectedNetwork!,
      );
    });
  }

  Future<void> _pickContact() async {
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      UiHelpers.showSnackBar(
        context,
        'Contact permission is required to pick a number',
        isError: true,
      );
      return;
    }
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final fullContact = await FlutterContacts.getContact(contact.id);
        if (fullContact != null && fullContact.phones.isNotEmpty) {
          String phone = fullContact.phones.first.number;
          phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          if (phone.startsWith('+234')) {
            phone = '0${phone.substring(4)}';
          } else if (phone.startsWith('234')) {
            phone = '0${phone.substring(3)}';
          }
          if (!phone.startsWith('0')) phone = '0$phone';
          if (phone.length > 11) phone = phone.substring(0, 11);
          setState(() => _phoneController.text = phone);
          _checkNetworkMismatch();
        }
      }
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(context, 'Failed to pick contact', isError: true);
    }
  }

  Future<void> _showConfirmationDialog() async {
    UiHelpers.dismissKeyboard(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNetwork == null) {
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
                _buildConfirmRow('Network', _selectedNetwork!),
                _buildConfirmRow('Phone Number', _phoneController.text.trim()),
                _buildConfirmRow(
                  'Airtime Amount',
                  'N${NumberFormat('#,##0').format(_airtimeAmount)}',
                ),
                _buildConfirmRow('Est. Conversion Rate', '$_displayRate%'),
                const Divider(height: 24),
                _buildConfirmRow(
                  'Est. You Will Receive',
                  'N${NumberFormat('#,##0.00').format(_receivableAmount)}',
                  isBold: true,
                ),
                if (_networkMismatchWarning != null) ...[
                  const SizedBox(height: 12),
                  Container(
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
                            '$_networkMismatchWarning This may still work if the number is ported.',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          'Final rate will be confirmed by the server. '
                          'Your request will be submitted for admin review and approval.',
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

  Future<void> _submitRequest() async {
    setState(() => _isProcessing = true);

    try {
      final authService = context.read<AuthProvider>().authService;
      final result = await authService.api.submitATCRequest(
        network: _selectedNetwork!,
        amount: _airtimeAmount,
        number: _phoneController.text.trim(),
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

  void _showSuccessDialog(Map<String, dynamic> data) {
    final transactionId = data['transaction_id']?.toString() ?? '';
    final sendTo = data['send_to']?.toString() ?? '';
    final youGet = (data['you_get'] as num?)?.toDouble() ?? 0.0;
    final ratePercent = data['rate_percent'];
    final int rate = ratePercent is int
        ? ratePercent
        : int.tryParse(ratePercent?.toString() ?? '') ?? _displayRate;

    setState(() => _apiRate = rate);

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
                          'Submit your request first — you\'ll receive the number to send airtime to after submission.',
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
                  else if (_networks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: TextButton.icon(
                          onPressed: _loadNetworks,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Failed to load networks. Tap to retry',
                          ),
                        ),
                      ),
                    )
                  else
                    NetworkSelector(
                      selectedNetwork: _selectedNetwork,
                      networks: _networks,
                      showDiscount: false,
                      onNetworkSelected: (airtimeNetwork) {
                        setState(() {
                          _selectedNetwork = airtimeNetwork.network;
                          _apiRate = null;
                          _networkMismatchWarning = null;
                        });
                        _checkNetworkMismatch();
                      },
                    ),
                  const SizedBox(height: 24),

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

                  // Network mismatch warning
                  if (_networkMismatchWarning != null) ...[
                    const SizedBox(height: 6),
                    Row(
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
                            '$_networkMismatchWarning This may still work if the number is ported.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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

                  // Conversion Display
                  if (_selectedNetwork != null && _airtimeAmount > 0) ...[
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
                          Text(
                            _apiRate != null
                                ? 'You Will Receive'
                                : 'Est. You Will Receive',
                            style: const TextStyle(
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
                            'Conversion Rate: $_displayRate%${_apiRate == null ? ' (estimated)' : ''}',
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

                  // Terms Checkbox
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

                  // Submit Button
                  CustomButton(
                    text: 'Submit Request',
                    icon: Icons.send,
                    onPressed: _showConfirmationDialog,
                    isLoading: _isProcessing,
                  ),
                  const SizedBox(height: 16),

                  // Important Notes
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
                          '- Submit your request first to get the number to send to\n'
                          '- Minimum conversion amount is N1,000\n'
                          '- Request will be reviewed by admin\n'
                          '- Cash credited after approval\n'
                          '- Processing time: 5-30 minutes',
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
