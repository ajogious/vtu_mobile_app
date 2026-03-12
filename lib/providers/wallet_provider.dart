import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';

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
    _loadCachedBalance();
  }

  /// On startup: load from cache or storage only (no API call yet).
  Future<void> _loadCachedBalance() async {
    final cached = CacheService.getCachedWalletBalance();
    if (cached != null) {
      _balance = cached;
      _lastUpdated = CacheService.getWalletBalanceTime();
      _isFromCache = true;
      notifyListeners();
      return;
    }

    // Fall back to stored user balance
    final user = _storage.getUser();
    if (user != null) {
      _balance = user.balance;
      _lastUpdated = DateTime.now();
      _isFromCache = false;
      notifyListeners();
    }
  }

  /// Primary method called by screens.
  /// - forceRefresh: true  → always hits the API (login, pull-to-refresh, post-transaction)
  /// - forceRefresh: false → serves from cache if available, otherwise hits API
  Future<bool> loadBalance({bool forceRefresh = false}) async {
    // Serve from cache if not forcing and cache is available
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

    // Hit the API
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final previousBalance = _balance;
      final result = await _authService.api.getWalletBalance();

      if (result.success && result.data != null) {
        final newBalance = result.data!;
        setBalance(newBalance);
        await _storage.updateUserBalance(_balance);
        _isLoading = false;
        notifyListeners();

        // If the balance went UP compared to before (external credit: admin
        // top-up or virtual account funding), fire a wallet notification.
        // Only do this on a forced refresh (not first-load) to avoid a
        // false positive on initial page load.
        if (forceRefresh &&
            newBalance > previousBalance &&
            previousBalance > 0) {
          final credited = newBalance - previousBalance;
          NotificationService.walletCredited(credited, 'Bank Transfer / Admin');
        }

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

  /// Kept for backward compatibility — delegates to loadBalance.
  Future<bool> fetchBalance({bool forceRefresh = false}) async {
    return loadBalance(forceRefresh: forceRefresh);
  }

  // Update balance locally and in cache
  void updateBalance(double newBalance) {
    setBalance(newBalance);
    _storage.updateUserBalance(newBalance);
  }

  // Update balance from user profile object
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
