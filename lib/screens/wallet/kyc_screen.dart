import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
// import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../../models/virtual_account_model.dart';

enum KycType { bvn, nin }

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  KycType _selectedType = KycType.bvn;
  bool _isLoading = false;
  List<VirtualAccount> _virtualAccounts = [];
  bool _verificationSuccessful = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  String? _validateKycNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your ${_selectedType == KycType.bvn ? "BVN" : "NIN"}';
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');

    if (_selectedType == KycType.bvn) {
      // BVN is 11 digits
      if (cleaned.length != 11) {
        return 'BVN must be 11 digits';
      }
      if (!RegExp(r'^\d{11}$').hasMatch(cleaned)) {
        return 'BVN must contain only numbers';
      }
    } else {
      // NIN is 11 digits
      if (cleaned.length != 11) {
        return 'NIN must be 11 digits';
      }
      if (!RegExp(r'^\d{11}$').hasMatch(cleaned)) {
        return 'NIN must contain only numbers';
      }
    }

    return null;
  }

  Future<void> _submitKyc() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.authService.api.verifyKyc(
      type: _selectedType == KycType.bvn ? 'bvn' : 'nin',
      value: _numberController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success && result.data != null) {
      setState(() {
        _virtualAccounts = result.data!;
        _verificationSuccessful = true;
      });

      // IMPORTANT: Update user KYC status in provider AND storage
      if (authProvider.user != null) {
        final updatedUser = authProvider.user!.copyWith(kycVerified: true);
        await authProvider.updateUser(updatedUser);
      }

      // ignore: use_build_context_synchronously
      UiHelpers.showSnackBar(context, result.message);
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'KYC verification failed',
        isError: true,
      );
    }
  }

  void _skip() {
    Navigator.pop(context, false);
  }

  void _done() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('KYC Verification'),
          centerTitle: true,
          actions: [
            if (!_verificationSuccessful)
              TextButton(onPressed: _skip, child: const Text('Skip')),
          ],
        ),
        body: SafeArea(
          child: _verificationSuccessful
              ? _buildSuccessView()
              : _buildVerificationForm(),
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Icon(
              Icons.verified_user,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Verify Your Identity',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Complete KYC verification to get dedicated virtual bank accounts for instant wallet funding',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // KYC Type Selection
            Text(
              'Select Verification Method',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // BVN Radio
            RadioListTile<KycType>(
              value: KycType.bvn,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _numberController.clear();
                });
              },
              title: const Text('Bank Verification Number (BVN)'),
              subtitle: const Text('11-digit BVN'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _selectedType == KycType.bvn
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // NIN Radio
            RadioListTile<KycType>(
              value: KycType.nin,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _numberController.clear();
                });
              },
              title: const Text('National Identity Number (NIN)'),
              subtitle: const Text('11-digit NIN'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _selectedType == KycType.nin
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Number Input
            CustomTextField(
              controller: _numberController,
              labelText: _selectedType == KycType.bvn ? 'BVN' : 'NIN',
              hintText:
                  'Enter your ${_selectedType == KycType.bvn ? "BVN" : "NIN"}',
              prefixIcon: Icons.credit_card,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: _validateKycNumber,
            ),
            const SizedBox(height: 32),

            // Submit Button
            CustomButton(
              text: 'Verify',
              onPressed: _submitKyc,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your information is secure and will only be used for account verification purposes.',
                      style: TextStyle(color: Colors.blue[900], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 80, color: Colors.green[600]),
          ),
          const SizedBox(height: 24),

          // Success Message
          Text(
            'Verification Successful!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your virtual bank accounts have been created',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Virtual Accounts
          Text(
            'Your Virtual Accounts',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ..._virtualAccounts.map(
            (account) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      account.accountName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            account.accountNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: account.accountNumber),
                              );
                              UiHelpers.showSnackBar(
                                context,
                                'Account number copied',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Done Button
          CustomButton(text: 'Done', onPressed: _done),
        ],
      ),
    );
  }
}
