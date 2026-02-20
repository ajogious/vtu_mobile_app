import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../widgets/pin_input.dart';
import '../widgets/custom_button.dart';
import '../../utils/ui_helpers.dart';

class SetPinScreen extends StatefulWidget {
  final bool isFirstTime;

  const SetPinScreen({super.key, this.isFirstTime = false});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isPinSet = false;
  bool _isLoading = false;

  void _onPinCompleted(String pin) {
    setState(() {
      _pin = pin;
    });
  }

  void _onConfirmPinCompleted(String pin) {
    setState(() {
      _confirmPin = pin;
    });
  }

  Future<void> _savePin() async {
    if (_pin.length != 5) {
      UiHelpers.showSnackBar(
        context,
        'Please enter a 5-digit PIN',
        isError: true,
      );
      return;
    }

    if (_confirmPin.length != 5) {
      UiHelpers.showSnackBar(context, 'Please confirm your PIN', isError: true);
      return;
    }

    if (_pin != _confirmPin) {
      UiHelpers.showSnackBar(context, 'PINs do not match', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Call API to set PIN
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.setPin(pin: _pin);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      // Save PIN locally
      await StorageService().savePin(_pin);

      UiHelpers.showSnackBar(context, result.message);

      // Navigate back or to dashboard
      if (widget.isFirstTime) {
        // First time - go back to dashboard
        Navigator.pop(context, true);
      } else {
        // From settings - go back
        Navigator.pop(context);
      }
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to set PIN',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Block back completely when setting PIN is mandatory
        if (widget.isFirstTime) {
          UiHelpers.showSnackBar(
            context,
            'You must set a transaction PIN before continuing',
            isError: true,
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Transaction PIN'),
          centerTitle: true,
          automaticallyImplyLeading: !widget.isFirstTime,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Icon
                Icon(
                  Icons.lock,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  _isPinSet ? 'Confirm Your PIN' : 'Create Transaction PIN',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  _isPinSet
                      ? 'Re-enter your 5-digit PIN to confirm'
                      : 'Create a 5-digit PIN to secure your transactions',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // PIN Input
                if (!_isPinSet) ...[
                  const Text(
                    'Enter PIN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  PinInput(
                    length: 5,
                    obscureText: true,
                    onCompleted: (pin) {
                      _onPinCompleted(pin);
                      setState(() {
                        _isPinSet = true;
                      });
                    },
                  ),
                ] else ...[
                  const Text(
                    'Confirm PIN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  PinInput(
                    length: 5,
                    obscureText: true,
                    onCompleted: _onConfirmPinCompleted,
                  ),
                ],
                const SizedBox(height: 40),

                // Submit button
                if (_isPinSet)
                  CustomButton(
                    text: 'Set PIN',
                    onPressed: _savePin,
                    isLoading: _isLoading,
                  ),

                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your PIN will be required for all purchases and wallet transactions.',
                          style: TextStyle(
                            color: Colors.blue[900],
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
      ),
    );
  }
}
