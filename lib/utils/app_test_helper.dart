import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/storage_service.dart';
import '../models/transaction_model.dart';

/// Helper to seed test data for manual testing / QA.
class AppTestHelper {
  static Future<void> seedTestData(BuildContext context) async {
    final walletProvider = context.read<WalletProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    // Seed wallet balance
    walletProvider.setBalance(15000);

    // Seed transactions
    final testTransactions = [
      Transaction(
        id: 'TEST001',
        type: TransactionType.airtime,
        network: 'MTN',
        amount: 200,
        status: TransactionStatus.success,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        beneficiary: '08012345678',
        reference: 'AIRTIME_TEST001',
        balanceBefore: 15200,
        balanceAfter: 15000,
      ),
      Transaction(
        id: 'TEST002',
        type: TransactionType.data,
        network: 'GLO',
        amount: 270,
        status: TransactionStatus.success,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        beneficiary: '08098765432',
        reference: 'DATA_TEST002',
        balanceBefore: 15470,
        balanceAfter: 15200,
        metadata: {'bundle': '1GB GLO CG', 'validity': '30 Days'},
      ),
      Transaction(
        id: 'TEST003',
        type: TransactionType.electricity,
        network: 'EKEDC',
        amount: 5000,
        status: TransactionStatus.success,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        beneficiary: '1234567890',
        reference: 'ELEC_TEST003',
        balanceBefore: 20470,
        balanceAfter: 15470,
        metadata: {
          'token': '1234-5678-9012-3456',
          'units': '45.2',
          'customer_name': 'John Doe',
          'meter_type': 'Prepaid',
        },
      ),
      Transaction(
        id: 'TEST004',
        type: TransactionType.walletFunding,
        network: 'Paystack',
        amount: 20000,
        status: TransactionStatus.success,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        reference: 'FUND_TEST004',
        balanceBefore: 470,
        balanceAfter: 20470,
      ),
      Transaction(
        id: 'TEST005',
        type: TransactionType.cable,
        network: 'DSTV',
        amount: 10500,
        status: TransactionStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        beneficiary: '9876543210',
        reference: 'CABLE_TEST005',
        balanceBefore: 31000,
        balanceAfter: 20470,
        metadata: {
          'customer_name': 'Jane Smith',
          'package': 'DStv Compact',
          'duration': '1 Month',
        },
      ),
    ];

    for (final t in testTransactions) {
      transactionProvider.addTransaction(t);
    }
  }

  static Future<void> clearTestData(BuildContext context) async {
    context.read<TransactionProvider>().clearTransactions();
    context.read<WalletProvider>().setBalance(0);
  }

  static Future<void> setPinForTesting() async {
    final storage = StorageService();
    await storage.savePin('12345');
  }
}
