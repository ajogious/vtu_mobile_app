import 'package:flutter/material.dart';
import 'config/theme_config.dart';
import 'models/user_model.dart';

void main() {
  // Test User model
  final testUser = User(
    id: 1,
    username: 'testuser',
    email: 'test@example.com',
    firstname: 'Test',
    lastname: 'User',
    phone: '08012345678',
    balance: 5000.0,
    kycVerified: true,
    referralCode: 'REFTEST123',
  );

  print('User created: ${testUser.fullName}');
  print('Balance: ₦${testUser.balance}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A3TECH DATA',
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(title: const Text('A3TECH DATA')),
        body: const Center(child: Text('Day 1 Afternoon Complete!')),
      ),
    );
  }
}
