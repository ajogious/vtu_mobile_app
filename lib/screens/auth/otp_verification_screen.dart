import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/pin_input.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _otp = '';
  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.verifyOtp(
      email: widget.email,
      otp: _otp,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result.success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );

      // Navigate to reset password
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email, otp: _otp),
        ),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Invalid OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.forgotPassword(email: widget.email);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result.success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );

      // Restart timer
      _startTimer();
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to resend OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Icon
              Icon(
                Icons.mark_email_read,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Enter the 6-digit code sent to\n${widget.email}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP Input
              PinInput(
                length: 6,
                onCompleted: (pin) {
                  setState(() {
                    _otp = pin;
                  });
                },
                onChanged: (pin) {
                  setState(() {
                    _otp = pin;
                  });
                },
              ),
              const SizedBox(height: 32),

              // Verify button
              CustomButton(
                text: 'Verify OTP',
                onPressed: _verifyOTP,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive the code? "),
                  if (_resendTimer > 0)
                    Text(
                      'Resend in ${_resendTimer}s',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading ? null : _resendOTP,
                      child: const Text('Resend OTP'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
