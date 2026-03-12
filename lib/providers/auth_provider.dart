import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../services/cache_service.dart';
import 'app_lock_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();
  final AppLockProvider _appLockProvider;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider(this._appLockProvider) {
    _loadUser();

    // Listen for unauthorized events globally
    ApiService.onUnauthenticated.stream.listen((_) {
      if (_user != null && !_isLoading) {
        logout();
      }
    });
  }

  // Load user from storage on startup
  void _loadUser() {
    _user = _storage.getUser();
  }

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);

      if (result.success && result.data != null) {
        _user = result.data;
        // Always keep the cached password fresh so biometrics always has valid
        // credentials — whether biometrics is currently enabled or not.
        await _storage.savePassword(password);

        // Reset lock timer on fresh login
        _appLockProvider.unlock();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Login failed';
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

  // Login with Biometrics
  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Authenticate with biometrics natively
      final authResult = await BiometricService.authenticateForAppUnlock();

      if (authResult != BiometricResult.success) {
        if (authResult != BiometricResult.cancelled) {
          _error = 'Biometric authentication failed';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Retrieve credentials
      final password = await _storage.getPassword();
      final username = _storage.getLastUsername();

      if (password == null ||
          password.isEmpty ||
          username == null ||
          username.isEmpty) {
        _error = 'No saved credentials found. Please login manually first.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Login normally under the hood
      final result = await _authService.login(username, password);

      if (result.success && result.data != null) {
        _user = result.data;

        // Reset lock timer on fresh login
        _appLockProvider.unlock();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Login failed';
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

  // Register
  Future<bool> register({
    required String firstname,
    required String lastname,
    required String username,
    required String email,
    required String phone,
    required String password,
    String? refer,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        firstname: firstname,
        lastname: lastname,
        username: username,
        email: email,
        phone: phone,
        password: password,
        refer: refer,
      );

      if (result.success) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Registration failed';
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

  /// Logout — clears user session, all caches, and notifies listeners.
  /// Call clearProviders() from the UI to also reset wallet/transaction state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();

    // Clear all cached data so next user starts fresh
    CacheService.clearAll();

    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Refresh user data from API (GET /user/me.php)
  Future<bool> refreshUser() async {
    try {
      final result = await _authService.api.getMe();
      if (result.success && result.data != null) {
        // The profile endpoint does NOT return bank account numbers or always
        // return pin_set — only the login response does. Preserve those fields
        // from the current user so refreshUser() doesn't wipe them.
        final fresh = result.data!;
        _user = fresh.copyWith(
          wemaAccount: fresh.wemaAccount ?? _user?.wemaAccount,
          moniepointAccount:
              fresh.moniepointAccount ?? _user?.moniepointAccount,
          sterlingAccount: fresh.sterlingAccount ?? _user?.sterlingAccount,
          // Preserve pinSet — if profile API doesn't return it, keep existing
          pinSet: fresh.pinSet || (_user?.pinSet ?? false),
        );
        await _storage.saveUser(_user!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Update user (and save to storage)
  Future<void> updateUser(User user) async {
    _user = user;
    await _storage.saveUser(user);
    notifyListeners();
  }

  // Check token validity; silently refresh if expired but credentials exist.
  Future<bool> checkTokenValidity() async {
    final isValid = await _authService.isLoggedIn();
    if (!isValid) {
      // Attempt a silent refresh using the stored credentials before forcing
      // the user back to the login screen.
      final refreshed = await _authService.silentRefresh();
      if (refreshed) {
        // Reload the fresh user data that silentRefresh() saved to storage.
        _user = _storage.getUser();
        notifyListeners();
        return true;
      }

      // Could not refresh — clear the stale user state.
      _user = null;
      notifyListeners();
      return false;
    }
    return true;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get auth service for other uses
  AuthService get authService => _authService;
}
