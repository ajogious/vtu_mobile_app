import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pinController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric';
  IconData _biometricIcon = Icons.fingerprint;
  int _failedAttempts = 0;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAutoUnlock();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAndAutoUnlock() async {
    final isEnabled = BiometricService.isBiometricEnabled();
    final canAuth = await BiometricService.canAuthenticate();

    if (isEnabled && canAuth) {
      final label = await BiometricService.getBiometricLabel();
      final icon = await BiometricService.getBiometricIcon();

      if (!mounted) return;

      setState(() {
        _biometricAvailable = true;
        _biometricLabel = label;
        _biometricIcon = icon;
      });

      // Auto-trigger biometric on screen open
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;

    setState(() {
      _isLoading = true;
    });

    final result = await BiometricService.authenticateForAppUnlock();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result == BiometricResult.success) {
      widget.onUnlocked();
    } else if (result == BiometricResult.lockedOut) {
      setState(() {
        _errorMessage = 'Biometric locked. Please use PIN.';
        _biometricAvailable = false;
      });
    } else if (result == BiometricResult.notAvailable) {
      setState(() {
        _biometricAvailable = false;
      });
    }
  }

  void _verifyPin() async {
    if (_isLocked) {
      UiHelpers.showSnackBar(
        context,
        'Too many failed attempts. Please wait.',
        isError: true,
      );
      return;
    }

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
      _failedAttempts = 0;
      widget.onUnlocked();
    } else {
      _failedAttempts++;

      if (_failedAttempts >= 3) {
        setState(() {
          _isLocked = true;
          _errorMessage = 'Too many failed attempts. Try again in 30 seconds.';
          _pinController.clear();
        });

        // Unlock after 30 seconds
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _failedAttempts = 0;
              _errorMessage = 'You can try again now.';
            });
          }
        });
      } else {
        setState(() {
          _errorMessage =
              'Incorrect PIN. ${3 - _failedAttempts} attempt${3 - _failedAttempts > 1 ? 's' : ''} remaining.';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              const Icon(Icons.lock, size: 80, color: Colors.grey),
              const SizedBox(height: 24),

              // Title
              const Text(
                'App Locked',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN to continue',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Biometric Button
              if (_biometricAvailable && !_isLoading && !_isLocked) ...[
                ElevatedButton.icon(
                  onPressed: _tryBiometric,
                  icon: Icon(_biometricIcon, size: 28),
                  label: Text(
                    'Use $_biometricLabel',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Loading
              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
              ],

              // PIN Input
              if (!_isLoading) ...[
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 5,
                  autofocus: !_biometricAvailable,
                  enabled: !_isLocked,
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
                    fillColor: _isLocked ? Colors.grey[200] : null,
                    filled: _isLocked,
                  ),
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  onSubmitted: (_) => _verifyPin(),
                  onChanged: (value) {
                    if (_errorMessage.isNotEmpty && !_isLocked) {
                      setState(() {
                        _errorMessage = '';
                      });
                    }
                    if (value.length == 5) {
                      _verifyPin();
                    }
                  },
                ),
                const SizedBox(height: 24),

                if (!_isLocked)
                  ElevatedButton(
                    onPressed: _verifyPin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Unlock', style: TextStyle(fontSize: 16)),
                  ),

                // Locked countdown
                if (_isLocked) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Account locked. Please wait 30 seconds.',
                          style: TextStyle(
                            color: Colors.red[900],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
