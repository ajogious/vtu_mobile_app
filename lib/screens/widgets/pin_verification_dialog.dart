import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';

/// A dialog that collects the user's transaction PIN.
///
/// The PIN is returned to the caller and validated by the server
/// during the actual purchase/withdrawal request.
/// Biometric authentication is for LOGIN only — not transactions.
class PinVerificationDialog extends StatefulWidget {
  final String? title;
  final String? subtitle;

  const PinVerificationDialog({
    super.key,
    this.title,
    this.subtitle,
  });

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitPin() {
    final pin = _pinController.text.trim();
    if (pin.length < 5) {
      setState(() => _errorMessage = 'Please enter your 5-digit PIN');
      return;
    }
    // Return PIN to caller — server validates it during the transaction.
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
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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

                // PIN input — auto-submits at 5 digits
                TextField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
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
                    errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
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
                    if (value.length == 5) _submitPin();
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submitPin,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Shows the PIN collection dialog.
///
/// Returns the PIN string the user typed, or null if cancelled.
/// The PIN is NOT pre-verified — it is sent to the server with the
/// purchase/withdrawal request, and the server validates it.
///
/// [serverPinSet] — if false AND no local PIN cached, shows a snackbar
/// prompting the user to set a PIN first.
///
/// [allowBiometric] — kept for backwards compatibility, no longer used.
/// Biometric is for LOGIN only.
Future<String?> showPinVerificationDialog(
  BuildContext context, {
  String? title,
  String? subtitle,
  bool allowBiometric = true, // ignored — biometric is login-only
  bool serverPinSet = false,
}) async {
  final storage = StorageService();
  final localPinExists = await storage.hasPin();

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
    ),
  );

  return (result != null && result.isNotEmpty) ? result : null;
}

/// Helper for sensitive actions — re-authenticates via PIN and returns bool.
Future<bool> requireReAuthentication(
  BuildContext context, {
  required String action,
}) async {
  final pin = await showPinVerificationDialog(
    context,
    title: 'Security Check',
    subtitle: 'Re-enter your PIN to $action',
  );
  return pin != null;
}
