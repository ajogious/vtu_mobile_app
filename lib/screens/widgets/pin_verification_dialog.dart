// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';

/// A bottom-sheet that lets the user confirm a transaction via PIN.
///
/// Returns the PIN string when the user uses PIN.
/// Returns `null` if the user cancels.

class PinVerificationSheet extends StatefulWidget {
  final String? title;
  final String? subtitle;

  const PinVerificationSheet({super.key, this.title, this.subtitle});

  @override
  State<PinVerificationSheet> createState() => _PinVerificationSheetState();
}

class _PinVerificationSheetState extends State<PinVerificationSheet>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 5;

  String _enteredPin = '';
  String _errorMessage = '';

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(-0.04, 0),
          end: const Offset(0.04, 0),
        ),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.04, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= _pinLength) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });
    if (_enteredPin.length == _pinLength) _submitPin();
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _submitPin() {
    final pin = _enteredPin;
    if (pin.length < _pinLength) {
      setState(() => _errorMessage = 'Enter all 5 digits');
      return;
    }
    // Return PIN to caller — server validates during the transaction
    Navigator.pop(context, pin);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Lock icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),

            // Title & subtitle
            Text(
              widget.title ?? 'Confirm Transaction',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 28),

            // PIN dots
            SlideTransition(
              position: _shakeAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_errorMessage.isNotEmpty
                                ? colorScheme.error
                                : colorScheme.primary)
                          : Colors.transparent,
                      border: Border.all(
                        color: _errorMessage.isNotEmpty
                            ? colorScheme.error
                            : colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),

            // Error
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : const SizedBox(height: 4),
            ),
            const SizedBox(height: 12),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildKeyRow(['1', '2', '3'], colorScheme),
                  const SizedBox(height: 10),
                  _buildKeyRow(['4', '5', '6'], colorScheme),
                  const SizedBox(height: 10),
                  _buildKeyRow(['7', '8', '9'], colorScheme),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 64, height: 56), // Placeholder for symmetry
                      _buildDigitButton('0', colorScheme),
                      _TxKeyButton(
                        onTap: _onDelete,
                        colorScheme: colorScheme,
                        child: Icon(
                          Icons.backspace_outlined,
                          size: 22,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d, cs)).toList(),
    );
  }

  Widget _buildDigitButton(String digit, ColorScheme cs) {
    return _TxKeyButton(
      onTap: () => _onDigitPressed(digit),
      colorScheme: cs,
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

/// Small square key button used inside the transaction sheet keypad
class _TxKeyButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final ColorScheme colorScheme;

  const _TxKeyButton({
    required this.onTap,
    required this.child,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colorScheme.primary.withValues(alpha: 0.12),
        child: Container(
          width: 64,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the bottom-sheet PIN dialog for a transaction.
///
/// Returns:
/// • a 5-digit PIN string → user entered PIN (server validates it)
/// • `null` → user cancelled
Future<String?> showPinVerificationDialog(
  BuildContext context, {
  String? title,
  String? subtitle,
  bool allowBiometric = true, // kept for backwards compat
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
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PinVerificationSheet(title: title, subtitle: subtitle),
  );
}

/// Helper for sensitive actions — re-authenticates via PIN.
Future<bool> requireReAuthentication(
  BuildContext context, {
  required String action,
}) async {
  final result = await showPinVerificationDialog(
    context,
    title: 'Security Check',
    subtitle: 'Verify your identity to $action',
  );
  return result != null;
}
