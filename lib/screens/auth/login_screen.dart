import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/loading_overlay.dart';
import '../../utils/ui_helpers.dart';
import '../../services/biometric_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  bool _canUseBiometrics = false;
  IconData? _biometricIcon;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final storage = StorageService();
    final password = await storage.getPassword();
    final username = storage.getLastUsername();

    if (password != null &&
        password.isNotEmpty &&
        username != null &&
        username.isNotEmpty) {
      final isSupported = await BiometricService.canAuthenticate();
      final isEnabled = storage.getBiometricEnabled();
      if (isSupported && isEnabled) {
        final icon = await BiometricService.getBiometricIcon();
        if (mounted) {
          setState(() {
            _canUseBiometrics = true;
            _biometricIcon = icon;
          });
        }
      }
    }
  }

  void _loadRememberMe() {
    final storage = StorageService();
    _rememberMe = storage.getRememberMe();
    if (_rememberMe) {
      final username = storage.getLastUsername();
      if (username != null) {
        _usernameController.text = username;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final storage = StorageService();
    await storage.saveRememberMe(_rememberMe);
    
    // We always need to know who the last user was for Biometrics to work silently.
    await storage.saveLastUsername(_usernameController.text.trim());

    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      UiHelpers.showSnackBar(
        context,
        authProvider.error ?? 'Login failed',
        isError: true,
      );
    }
  }

  Future<void> _loginWithBiometrics() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithBiometrics();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (authProvider.error != null &&
        authProvider.error != 'Biometric authentication failed') {
      UiHelpers.showSnackBar(context, authProvider.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return LoadingOverlay(
          isLoading: authProvider.isLoading,
          message: 'Logging in...',
          child: GestureDetector(
            onTap: () => UiHelpers.dismissKeyboard(context),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),

                        // Logo
                        Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'images/logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.phone_android,
                                  size: 60,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Welcome text
                        Text(
                          'Welcome Back!',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to your account',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Username field
                        CustomTextField(
                          controller: _usernameController,
                          labelText: 'Username',
                          hintText: 'Enter your username',
                          prefixIcon: Icons.person,
                          textCapitalization: TextCapitalization.none,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your username';
                            }
                            if (value.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        CustomTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icons.lock,
                          obscureText: true,
                          showPasswordToggle: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),

                        // Remember me & Forgot password
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text('Forgot Password?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'Login',
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _login,
                                isLoading: authProvider.isLoading,
                              ),
                            ),
                            if (_canUseBiometrics) ...[
                              const SizedBox(width: 16),
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _biometricIcon ?? Icons.fingerprint,
                                  ),
                                  color: Theme.of(context).primaryColor,
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _loginWithBiometrics,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            TextButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                              child: const Text('Register'),
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
      },
    );
  }
}
