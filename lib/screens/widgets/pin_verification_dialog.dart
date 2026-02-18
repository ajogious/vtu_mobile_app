import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';

class PinVerificationDialog extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final bool allowBiometric;

  const PinVerificationDialog({
    super.key,
    this.title,
    this.subtitle,
    this.allowBiometric = true,
  });

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric';
  IconData _biometricIcon = Icons.fingerprint;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    if (!widget.allowBiometric) return;

    final isEnabled = BiometricService.isBiometricEnabled();
    if (!isEnabled) return;

    final canAuth = await BiometricService.canAuthenticate();
    if (!canAuth) return;

    final label = await BiometricService.getBiometricLabel();
    final icon = await BiometricService.getBiometricIcon();

    if (!mounted) return;

    setState(() {
      _biometricAvailable = true;
      _biometricLabel = label;
      _biometricIcon = icon;
    });

    // Auto-trigger biometric
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;

    setState(() {
      _isLoading = true;
    });

    final result = await BiometricService.authenticateForTransaction(
      transactionDescription: widget.subtitle ?? 'Confirm transaction',
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case BiometricResult.success:
        Navigator.pop(context, true);
        break;
      case BiometricResult.cancelled:
        // User cancelled, let them use PIN
        break;
      case BiometricResult.lockedOut:
        setState(() {
          _errorMessage = 'Biometric locked. Please use PIN.';
        });
        break;
      case BiometricResult.notAvailable:
      case BiometricResult.notEnrolled:
        setState(() {
          _biometricAvailable = false;
        });
        break;
      default:
        setState(() {
          _errorMessage = 'Biometric failed. Please use PIN.';
        });
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length < 5) {
      setState(() {
        _errorMessage = 'Please enter your 5-digit PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final storage = StorageService();
    final isValid = await storage.verifyPin(pin);

    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _pinController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Theme.of(context).primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  widget.title ?? 'Enter PIN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),

                // Biometric button (if available)
                if (_biometricAvailable && !_isLoading) ...[
                  OutlinedButton.icon(
                    onPressed: _tryBiometric,
                    icon: Icon(_biometricIcon),
                    label: Text('Use $_biometricLabel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or enter PIN',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Loading indicator
                if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],

                // PIN Input
                if (!_isLoading) ...[
                  TextField(
                    controller: _pinController,
                    focusNode: _focusNode,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 5,
                    autofocus: !_biometricAvailable,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '•  •  •  •  •',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      errorText: _errorMessage.isNotEmpty
                          ? _errorMessage
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    onSubmitted: (_) => _verifyPin(),
                    onChanged: (value) {
                      if (_errorMessage.isNotEmpty) {
                        setState(() {
                          _errorMessage = '';
                        });
                      }
                      if (value.length == 5) {
                        _verifyPin();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          if (!_isLoading)
            ElevatedButton(onPressed: _verifyPin, child: const Text('Verify')),
        ],
      ),
    );
  }
}

/// Helper function to show PIN verification dialog
Future<bool> showPinVerificationDialog(
  BuildContext context, {
  String? title,
  String? subtitle,
  bool allowBiometric = true,
}) async {
  final storage = StorageService();

  // Check if PIN has been set
  if (!await storage.hasPin()) {
    UiHelpers.showSnackBar(
      context,
      'Please set a PIN first in Settings',
      isError: true,
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinVerificationDialog(
      title: title,
      subtitle: subtitle,
      allowBiometric: allowBiometric,
    ),
  );

  return result ?? false;
}

/// Helper for sensitive actions (re-authentication)
Future<bool> requireReAuthentication(
  BuildContext context, {
  required String action,
}) async {
  return showPinVerificationDialog(
    context,
    title: 'Security Check',
    subtitle: 'Re-enter your PIN to $action',
    allowBiometric: true,
  );
}
