// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/loading_overlay.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.forgotPassword(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      UiHelpers.showSnackBar(context, result.message);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OtpVerificationScreen(email: _emailController.text.trim()),
        ),
      );
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to send OTP',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Sending OTP...',
      child: GestureDetector(
        onTap: () => UiHelpers.dismissKeyboard(context),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Forgot Password'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Icon
                    Icon(
                      Icons.lock_reset,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Reset Password',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      'Enter your email address and we\'ll send you a code to reset your password',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      validator: Validators.email,
                      onSubmitted: (_) => _sendOTP(),
                    ),
                    const SizedBox(height: 32),

                    // Send OTP button
                    CustomButton(
                      text: 'Send OTP',
                      onPressed: _isLoading ? null : _sendOTP,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 24),

                    // Back to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Remember your password? '),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
