import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/transaction_model.dart';

class TransactionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<Transaction> get transactions => _transactions;
  List<Transaction> get recentTransactions => _transactions.take(5).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch transactions
  Future<bool> fetchTransactions({
    int page = 1,
    int limit = 10,
    String? type,
    String? status,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.api.getTransactions(
        page: page,
        limit: limit,
        type: type,
        status: status,
        search: search,
      );

      if (result.success && result.data != null) {
        _transactions = result.data!.transactions;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Failed to fetch transactions';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Add new transaction to list (after purchase)
  void addTransaction(Transaction transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  // Clear transactions
  void clearTransactions() {
    _transactions = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
