import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';

/// A dialog that collects the user's transaction PIN.
///
/// This dialog does NOT pre-verify the PIN locally or via API.
/// The PIN is returned to the caller and validated by the server
/// during the actual purchase/withdrawal request. If the PIN is
/// wrong, the server returns an error which the caller shows to
/// the user — same as any other API error.
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

    // Only offer biometrics if we have the PIN saved locally to forward.
    final hasLocalPin = await StorageService().hasPin();
    if (!hasLocalPin) return;

    final label = await BiometricService.getBiometricLabel();
    final icon = await BiometricService.getBiometricIcon();

    if (!mounted) return;

    setState(() {
      _biometricAvailable = true;
      _biometricLabel = label;
      _biometricIcon = icon;
    });

    // Auto-trigger biometric prompt
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;

    setState(() => _isLoading = true);

    final result = await BiometricService.authenticateForTransaction(
      transactionDescription: widget.subtitle ?? 'Confirm transaction',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case BiometricResult.success:
        final storedPin = await StorageService().getPin() ?? '';
        if (mounted && storedPin.isNotEmpty) {
          Navigator.pop(context, storedPin);
        }
        break;
      case BiometricResult.cancelled:
        break; // Let user type PIN
      case BiometricResult.lockedOut:
        setState(() {
          _errorMessage = 'Biometric locked. Please use PIN.';
        });
        break;
      default:
        setState(() {
          _biometricAvailable = false;
        });
    }
  }

  void _submitPin() {
    final pin = _pinController.text.trim();

    if (pin.length < 5) {
      setState(() {
        _errorMessage = 'Please enter your 5-digit PIN';
      });
      return;
    }

    // Return the PIN to the caller — server will validate it.
    Navigator.pop(context, pin);
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

                // Loading indicator (biometric only)
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
                    onSubmitted: (_) => _submitPin(),
                    onChanged: (value) {
                      if (_errorMessage.isNotEmpty) {
                        setState(() => _errorMessage = '');
                      }
                      if (value.length == 5) {
                        _submitPin();
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
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          if (!_isLoading)
            ElevatedButton(onPressed: _submitPin, child: const Text('Confirm')),
        ],
      ),
    );
  }
}

/// Shows a PIN collection dialog.
///
/// Returns the PIN string the user typed, or null if they cancelled.
/// The PIN is NOT pre-verified here — it is sent to the server with the
/// purchase/withdrawal request, and the server validates it.
///
/// [serverPinSet] — if false AND no local PIN cached, shows a prompt to
/// set a PIN first so the user knows they need to configure one.
Future<String?> showPinVerificationDialog(
  BuildContext context, {
  String? title,
  String? subtitle,
  bool allowBiometric = true,
  bool serverPinSet = false,
}) async {
  final storage = StorageService();
  final localPinExists = await storage.hasPin();

  // Only block if server also says no PIN is set — avoids false negatives
  // on fresh installs where the user's PIN exists on the server but hasn't
  // been cached locally yet.
  if (!localPinExists && !serverPinSet) {
    if (!context.mounted) return null;
    UiHelpers.showSnackBar(
      context,
      'Please set a transaction PIN first in Settings → Security',
      isError: true,
    );
    return null;
  }

  if (!context.mounted) return null;
  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinVerificationDialog(
      title: title,
      subtitle: subtitle,
      allowBiometric: allowBiometric,
    ),
  );

  return (result != null && result.isNotEmpty) ? result : null;
}

/// Helper for sensitive actions (re-authentication — returns bool not PIN)
Future<bool> requireReAuthentication(
  BuildContext context, {
  required String action,
}) async {
  final pin = await showPinVerificationDialog(
    context,
    title: 'Security Check',
    subtitle: 'Re-enter your PIN to $action',
    allowBiometric: true,
  );
  return pin != null;
}
