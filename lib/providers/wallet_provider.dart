import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';

class WalletProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();

  double _balance = 0.0;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  bool _isFromCache = false;

  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isFromCache => _isFromCache;

  WalletProvider() {
    _loadBalance();
  }

  // Load balance from cache first, then storage on startup
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.getCachedWalletBalance();
      if (cached != null) {
        _balance = cached;
        _lastUpdated = CacheService.getWalletBalanceTime();
        _isFromCache = true;
        notifyListeners();
        return;
      }
    }

    // Fall back to storage if no cache
    final user = _storage.getUser();
    if (user != null) {
      _balance = user.balance;
      _lastUpdated = DateTime.now();
      _isFromCache = false;
      notifyListeners();
    }
  }

  /// Public alias so screens can call `loadBalance(forceRefresh: true)`.
  Future<void> loadBalance({bool forceRefresh = false}) async {
    await _loadBalance(forceRefresh: forceRefresh);
  }

  // Fetch balance from API
  Future<bool> fetchBalance({bool forceRefresh = false}) async {
    // Serve from cache if not forcing refresh
    if (!forceRefresh) {
      final cached = CacheService.getCachedWalletBalance();
      if (cached != null) {
        _balance = cached;
        _lastUpdated = CacheService.getWalletBalanceTime();
        _isFromCache = true;
        notifyListeners();
        return true;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.api.getWalletBalance();

      if (result.success && result.data != null) {
        setBalance(result.data!);

        // Also keep storage in sync
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

  // Update balance locally and in cache
  void updateBalance(double newBalance) {
    setBalance(newBalance);
    _storage.updateUserBalance(newBalance);
  }

  // Update balance from user profile
  void updateFromUser(User user) {
    _balance = user.balance;
    _lastUpdated = DateTime.now();
    _isFromCache = false;

    CacheService.cacheWalletBalance(_balance);
    notifyListeners();
  }

  // Set balance, update cache and timestamp
  void setBalance(double amount) {
    _balance = amount;
    _lastUpdated = DateTime.now();
    _isFromCache = false;

    CacheService.cacheWalletBalance(amount);
    notifyListeners();
  }

  // Add to balance (for funding/refunds)
  void addBalance(double amount) {
    _balance += amount;
    _lastUpdated = DateTime.now();
    _isFromCache = false;

    CacheService.cacheWalletBalance(_balance);
    _storage.updateUserBalance(_balance);
    notifyListeners();
  }

  // Deduct from balance (for purchases)
  void deductBalance(double amount) {
    _balance -= amount;
    _lastUpdated = DateTime.now();
    _isFromCache = false;

    CacheService.cacheWalletBalance(_balance);
    _storage.updateUserBalance(_balance);
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
