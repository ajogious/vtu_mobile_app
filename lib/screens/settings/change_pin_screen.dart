import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../widgets/pin_input.dart';
import '../widgets/custom_button.dart';
import '../../utils/ui_helpers.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  String _oldPin = '';
  String _newPin = '';
  String _confirmPin = '';
  int _currentStep = 0; // 0: old, 1: new, 2: confirm
  bool _isLoading = false;

  void _onOldPinCompleted(String pin) async {
    setState(() {
      _oldPin = pin;
    });

    // Verify old PIN
    final isValid = await StorageService().verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _currentStep = 1;
      });
    } else {
      UiHelpers.showSnackBar(context, 'Incorrect PIN', isError: true);
      // Clear and retry
      setState(() {
        _oldPin = '';
      });
    }
  }

  void _onNewPinCompleted(String pin) {
    setState(() {
      _newPin = pin;
      _currentStep = 2;
    });
  }

  void _onConfirmPinCompleted(String pin) {
    setState(() {
      _confirmPin = pin;
    });
  }

  Future<void> _changePin() async {
    if (_newPin.length != 5) {
      UiHelpers.showSnackBar(
        context,
        'Please enter a 5-digit PIN',
        isError: true,
      );
      return;
    }

    if (_confirmPin.length != 5) {
      UiHelpers.showSnackBar(
        context,
        'Please confirm your new PIN',
        isError: true,
      );
      return;
    }

    if (_newPin != _confirmPin) {
      UiHelpers.showSnackBar(context, 'PINs do not match', isError: true);
      return;
    }

    if (_oldPin == _newPin) {
      UiHelpers.showSnackBar(
        context,
        'New PIN must be different from old PIN',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Call API to change PIN
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.changePin(
      oldPin: _oldPin,
      newPin: _newPin,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      // Update PIN locally
      await StorageService().savePin(_newPin);

      UiHelpers.showSnackBar(context, result.message);

      // Go back
      Navigator.pop(context);
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to change PIN',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Transaction PIN'),
        centerTitle: true,
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
                Icons.lock_reset,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _currentStep == 0
                    ? 'Enter Current PIN'
                    : _currentStep == 1
                    ? 'Enter New PIN'
                    : 'Confirm New PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                _currentStep == 0
                    ? 'Enter your current 5-digit PIN'
                    : _currentStep == 1
                    ? 'Create a new 5-digit PIN'
                    : 'Re-enter your new PIN to confirm',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(0),
                  _buildStepConnector(0),
                  _buildStepIndicator(1),
                  _buildStepConnector(1),
                  _buildStepIndicator(2),
                ],
              ),
              const SizedBox(height: 40),

              // PIN Input
              if (_currentStep == 0)
                PinInput(
                  length: 5,
                  obscureText: true,
                  onCompleted: _onOldPinCompleted,
                )
              else if (_currentStep == 1)
                PinInput(
                  length: 5,
                  obscureText: true,
                  onCompleted: _onNewPinCompleted,
                )
              else
                PinInput(
                  length: 5,
                  obscureText: true,
                  onCompleted: _onConfirmPinCompleted,
                ),
              const SizedBox(height: 40),

              // Submit button (only on last step)
              if (_currentStep == 2)
                CustomButton(
                  text: 'Change PIN',
                  onPressed: _changePin,
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
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose a PIN that is easy for you to remember but hard for others to guess.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step) {
    final isActive = _currentStep >= step;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isActive
            ? Icon(
                _currentStep > step ? Icons.check : Icons.lock,
                color: Colors.white,
                size: 20,
              )
            : Text(
                '${step + 1}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Container(
      width: 40,
      height: 2,
      color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
    );
  }
}
