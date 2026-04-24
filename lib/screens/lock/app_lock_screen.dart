import 'dart:ui';
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
  bool _isLoading = false; 
  bool _isBiometricLoading = false; 
  bool _isTryingBiometric = false; 
  bool _biometricAvailable = false;
  IconData _biometricIcon = Icons.fingerprint;
  int _failedAttempts = 0;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAutoUnlock();
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
      final icon = await BiometricService.getBiometricIcon();

      if (!mounted) return;

      setState(() {
        _biometricAvailable = true;
        _biometricIcon = icon;
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent, // Let the background blur show through
      child: Stack(
        children: [
          // Premium Frosted Glass Background Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          
          SafeArea(
            child: AnimatedPadding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sleek Top Lock Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Typography
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter your password to continue',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Biometric Symbol
                      if (_biometricAvailable && !_isBiometricLoading && !_isLocked) ...[
                        Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _tryBiometric,
                              borderRadius: BorderRadius.circular(40),
                              splashColor: colorScheme.primary.withValues(alpha: 0.2),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  color: colorScheme.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.05),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _biometricIcon,
                                  size: 44,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (_isBiometricLoading) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 32),
                      ],

                      // Password Input
                      CustomTextField(
                        controller: _passwordController,
                        focusNode: _focusNode,
                        autofocus: !_biometricAvailable,
                        obscureText: true,
                        showPasswordToggle: true,
                        keyboardType: TextInputType.visiblePassword,
                        enabled: !_isLocked && !_isLoading,
                        hintText: 'Password',
                        prefixIcon: Icons.lock_outline,
                        onSubmitted: (_) => _verifyPassword(),
                        onChanged: (value) {
                          if (_errorMessage.isNotEmpty && !_isLocked) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _errorMessage = '');
                            });
                          }
                        },
                      ),
                      
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _errorMessage.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),

                      // Unlock Button
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (!_isLocked)
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _verifyPassword,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Unlock',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Locked Countdown State
                      if (_isLocked) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, color: colorScheme.error),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Account locked. Please wait 30 seconds.',
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }
}
