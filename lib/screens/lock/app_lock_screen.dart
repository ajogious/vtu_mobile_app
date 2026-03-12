import 'package:flutter/material.dart';

import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../utils/ui_helpers.dart';
import '../widgets/custom_textfield.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';
  bool _isLoading = false; // password verify in progress
  bool _isBiometricLoading = false; // biometric prompt in progress
  bool _isTryingBiometric = false; // guard against concurrent biometric prompts
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric';
  IconData _biometricIcon = Icons.fingerprint;
  int _failedAttempts = 0;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAutoUnlock();
    // Request focus after the first frame so the keyboard appears
    // automatically — this is needed because the lock screen lives inside
    // MaterialApp.builder (outside the Navigator) and the TextField won't
    // auto-focus on its own in that context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isBiometricLoading) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
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
    // Prevent multiple simultaneous biometric prompts which can cause freezes
    if (_isTryingBiometric) return;

    setState(() {
      _isBiometricLoading = true;
      _isTryingBiometric = true;
    });

    final result = await BiometricService.authenticateForAppUnlock();

    if (!mounted) return;

    setState(() {
      _isBiometricLoading = false;
      _isTryingBiometric = false;
    });

    if (result == BiometricResult.success) {
      widget.onUnlocked();
    } else if (result == BiometricResult.lockedOut) {
      setState(() {
        _errorMessage = 'Biometric locked. Please use your password.';
        _biometricAvailable = false;
      });
    } else if (result == BiometricResult.notAvailable ||
        result == BiometricResult.notEnrolled) {
      setState(() {
        _biometricAvailable = false;
      });
    }
    // For cancelled or failed: just show the screen — user can tap the button again.
  }

  void _verifyPassword() async {
    if (_isLocked) {
      UiHelpers.showSnackBar(
        context,
        'Too many failed attempts. Please wait.',
        isError: true,
      );
      return;
    }

    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
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
    final savedPassword = await storage.getPassword();
    final isValid = savedPassword != null && savedPassword == password;

    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      _failedAttempts = 0;
      widget.onUnlocked();
    } else {
      _failedAttempts++;

      if (_failedAttempts >= 5) {
        setState(() {
          _isLocked = true;
          _errorMessage = 'Too many failed attempts. Try again in 30 seconds.';
        });
        _passwordController.clear();

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
              'Incorrect password. ${5 - _failedAttempts} attempt${5 - _failedAttempts > 1 ? 's' : ''} remaining.';
        });
        _passwordController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48, // account for the 24px padding top + bottom
            ),
            child: IntrinsicHeight(
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
                    'Enter your account password to continue',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Biometric Button
                  if (_biometricAvailable &&
                      !_isBiometricLoading &&
                      !_isLocked) ...[
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

                  // Biometric loading indicator (separate from password loading)
                  if (_isBiometricLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 24),
                  ],

                  // Password Input — always kept in the widget tree so Flutter
                  // never destroys the TextField and loses focus/input state.
                  CustomTextField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    autofocus: true,
                    obscureText: true,
                    showPasswordToggle: true,
                    keyboardType: TextInputType.visiblePassword,
                    enabled: !_isLocked && !_isLoading,
                    hintText: 'Password',
                    prefixIcon: Icons.lock,
                    onSubmitted: (_) => _verifyPassword(),
                    onChanged: (value) {
                      if (_errorMessage.isNotEmpty && !_isLocked) {
                        setState(() {
                          _errorMessage = '';
                        });
                      }
                    },
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Unlock button / password-verify spinner
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (!_isLocked)
                    ElevatedButton(
                      onPressed: _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Unlock',
                        style: TextStyle(fontSize: 16),
                      ),
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
                          Expanded(
                            child: Text(
                              'Account locked. Please wait 30 seconds.',
                              style: TextStyle(
                                color: Colors.red[900],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
