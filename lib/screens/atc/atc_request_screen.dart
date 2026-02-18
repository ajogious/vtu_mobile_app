import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../../models/transaction_model.dart';
import '../widgets/pin_verification_dialog.dart';

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

  final Map<String, double> _conversionRates = {
    'MTN': 0.85,
    'GLO': 0.83,
    'AIRTEL': 0.84,
    '9MOBILE': 0.82,
  };

  double get _conversionRate => _conversionRates[_selectedNetwork] ?? 0.85;

  double get _airtimeAmount {
    final amount = double.tryParse(_amountController.text.trim());
    return amount ?? 0;
  }

  double get _receivableAmount => _airtimeAmount * _conversionRate;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
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

          if (!phone.startsWith('0')) {
            phone = '0$phone';
          }

          if (phone.length > 11) {
            phone = phone.substring(0, 11);
          }

          setState(() {
            _phoneController.text = phone;
          });
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

    // FIX: Wrap dialog Column in ConstrainedBox + SingleChildScrollView
    // so it never overflows on small screens
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
                  '₦${NumberFormat('#,##0').format(_airtimeAmount)}',
                ),
                _buildConfirmRow(
                  'Conversion Rate',
                  '${(_conversionRate * 100).toInt()}%',
                ),
                const Divider(height: 24),
                _buildConfirmRow(
                  'You Will Receive',
                  '₦${NumberFormat('#,##0.00').format(_receivableAmount)}',
                  isBold: true,
                ),
                const SizedBox(height: 16),
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

    if (confirmed == true) {
      _submitRequest();
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

  Future<void> _submitRequest() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Re-authentication for large amounts
      if (_airtimeAmount >= 10000) {
        final reAuthenticated = await requireReAuthentication(
          context,
          action: 'authorize this large transaction',
        );

        if (!reAuthenticated) {
          setState(() {
            _isProcessing = false;
          });
          UiHelpers.showSnackBar(
            context,
            'Re-authentication failed',
            isError: true,
          );
          return;
        }
      }

      final user = context.read<AuthProvider>().user;
      final transaction = Transaction(
        id: 'ATC${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.atc,
        network: _selectedNetwork!,
        amount: _airtimeAmount,
        status: TransactionStatus.pending,
        createdAt: DateTime.now(),
        beneficiary: _phoneController.text.trim(),
        reference: 'ATCREQ${DateTime.now().millisecondsSinceEpoch}',
        balanceBefore: 0,
        balanceAfter: 0,
        metadata: {
          'conversion_rate': _conversionRate,
          'receivable_amount': _receivableAmount,
          'user_name': '${user?.firstname ?? ''} ${user?.lastname ?? ''}',
          'user_phone': user?.phone ?? '',
        },
      );

      context.read<TransactionProvider>().addTransaction(transaction);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showSuccessDialog(transaction.reference!);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      UiHelpers.showSnackBar(
        context,
        'Failed to submit request: $e',
        isError: true,
      );
    }
  }

  void _showSuccessDialog(String reference) {
    showDialog(
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
              'Request Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: $reference',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
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
                      'Your request has been sent. You\'ll be notified when it\'s approved or rejected.',
                      style: TextStyle(color: Colors.blue[900], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('View Requests'),
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
        body: SingleChildScrollView(
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
                        'Send airtime from your phone to the number provided, then submit this form. You\'ll receive cash in your wallet after approval.',
                        style: TextStyle(color: Colors.blue[800], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Network Selector
                NetworkSelector(
                  selectedNetwork: _selectedNetwork,
                  onNetworkSelected: (network) {
                    setState(() {
                      _selectedNetwork = network;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Phone Number
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
                    // Updated minimum from ₦100 → ₦1,000
                    if (amount == null || amount < 1000) {
                      return 'Minimum amount is ₦1,000';
                    }
                    if (amount > 50000) {
                      return 'Maximum amount is ₦50,000';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
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
                        const Text(
                          'You Will Receive',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₦${NumberFormat('#,##0.00').format(_receivableAmount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Conversion Rate: ${(_conversionRate * 100).toInt()}%',
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
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value ?? false;
                    });
                  },
                  title: const Text(
                    'I confirm that I have sent the airtime and accept the terms',
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
                        '• Only submit after sending airtime\n'
                        '• Minimum conversion amount is ₦1,000\n'
                        '• Request will be reviewed by admin\n'
                        '• Cash credited after approval\n'
                        '• Processing time: 5-30 minutes',
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
    );
  }
}
