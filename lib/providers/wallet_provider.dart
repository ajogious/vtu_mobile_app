import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class WalletProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();

  double _balance = 0.0;
  bool _isLoading = false;
  String? _error;

  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WalletProvider() {
    _loadBalance();
  }

  // Load balance from storage on startup
  void _loadBalance() {
    final user = _storage.getUser();
    if (user != null) {
      _balance = user.balance;
    }
  }

  // Fetch balance from API
  Future<bool> fetchBalance() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.api.getWalletBalance();

      if (result.success && result.data != null) {
        _balance = result.data!;

        // Update user in storage
        await _storage.updateUserBalance(_balance);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Failed to fetch balance';
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

  // Update balance locally
  void updateBalance(double newBalance) {
    _balance = newBalance;
    _storage.updateUserBalance(newBalance);
    notifyListeners();
  }

  // Deduct from balance (for purchases)
  void deductBalance(double amount) {
    _balance -= amount;
    _storage.updateUserBalance(_balance);
    notifyListeners();
  }

  // Add to balance (for funding/refunds)
  void addBalance(double amount) {
    _balance += amount;
    _storage.updateUserBalance(_balance);
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
