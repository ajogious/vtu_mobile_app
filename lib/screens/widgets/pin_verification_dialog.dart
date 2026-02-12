// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../widgets/pin_input.dart';

class PinVerificationDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const PinVerificationDialog({
    super.key,
    this.title = 'Enter PIN',
    this.subtitle,
  });

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  String _pin = '';
  bool _isVerifying = false;
  String? _error;

  void _onPinCompleted(String pin) async {
    setState(() {
      _pin = pin;
      _isVerifying = true;
      _error = null;
    });

    // Verify PIN
    final isValid = await StorageService().verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      // PIN correct - return true
      Navigator.pop(context, true);
    } else {
      // PIN incorrect
      setState(() {
        _isVerifying = false;
        _error = 'Incorrect PIN. Please try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Icon(Icons.lock, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinInput(length: 5, obscureText: true, onCompleted: _onPinCompleted),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isVerifying) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Helper function to show dialog
Future<bool> showPinVerificationDialog(
  BuildContext context, {
  String title = 'Enter PIN',
  String? subtitle,
}) async {
  // Check if PIN is set
  final hasPin = await StorageService().hasPin();

  if (!hasPin) {
    // No PIN set - return true (allow action)
    return true;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        PinVerificationDialog(title: title, subtitle: subtitle),
  );

  return result ?? false;
}
