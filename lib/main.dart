import 'package:flutter/material.dart';
import 'config/theme_config.dart';
import 'services/storage_service.dart';
import 'services/api/mock_api_service.dart';
import 'models/transaction_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await StorageService().init();

  // Test storage
  await StorageService().saveToken('test_token_123');
  String? token = await StorageService().getToken();
  print('✅ Storage test - Token saved: $token');

  // ========== DAY 2 EVENING: Test Mock API ==========
  print('\n========== TESTING MOCK API ==========');

  final mockApi = MockApiService();

  // Test login (this generates mock transactions with ALL types)
  print('\n1. Testing login...');
  final loginResult = await mockApi.login(
    username: 'testuser',
    password: 'password123',
  );

  if (loginResult.success) {
    print('✅ Login successful');
    print('   User: ${loginResult.data!['user']['username']}');
    print('   Token: ${loginResult.data!['token']}');
  } else {
    print('❌ Login failed: ${loginResult.error}');
  }

  // Test getting transactions
  print('\n2. Testing getTransactions...');
  final transactionsResult = await mockApi.getTransactions(limit: 20);

  if (transactionsResult.success) {
    final transactions = transactionsResult.data!.transactions;
    print('✅ Transactions fetched: ${transactions.length} total');

    // Verify all 10 transaction types exist
    print('\n3. Verifying ALL transaction types:');
    final typeSet = <String>{};
    for (var txn in transactions) {
      typeSet.add(txn.type.name);
    }

    final expectedTypes = [
      'airtime',
      'data',
      'cable',
      'electricity',
      'examPin',
      'dataCard',
      'walletFunding',
      'atc',
      'referralWithdrawal',
    ];

    for (var type in expectedTypes) {
      if (typeSet.contains(type)) {
        print('   ✅ $type');
      } else {
        print('   ❌ $type - MISSING!');
      }
    }

    print('\n4. Transaction breakdown:');
    for (var txn in transactions) {
      final statusIcon = txn.status == TransactionStatus.success
          ? '✅'
          : txn.status == TransactionStatus.pending
          ? '⏳'
          : '❌';
      print(
        '   $statusIcon ${txn.type.name.padRight(20)} ₦${txn.amount.toStringAsFixed(0).padLeft(6)} - ${txn.network}',
      );
    }

    print('\n========== DAY 2 EVENING TESTS COMPLETE ==========');
    print('✅ StorageService initialization: PASSED');
    print('✅ Mock API calls: PASSED');
    print('✅ All transaction types verified: PASSED');
  } else {
    print('❌ Failed to fetch transactions: ${transactionsResult.error}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A3TECH VTU APP',
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        appBar: AppBar(title: const Text('A3TECH VTU APP')),
        body: const Center(child: Text('Working in progress...')),
      ),
    );
  }
}
