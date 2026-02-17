import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;
  FlutterSecureStorage? _secureStorage;

  // ========== PREFERENCE KEYS ==========

  static const String _notificationTransactions = 'notification_transactions';
  static const String _notificationWallet = 'notification_wallet';
  static const String _notificationReferrals = 'notification_referrals';
  static const String _notificationPromotional = 'notification_promotional';
  static const String _biometricEnabled = 'biometric_enabled';

  // Initialize storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Only initialize flutter_secure_storage on non-web platforms
    if (!kIsWeb) {
      _secureStorage = const FlutterSecureStorage();
    }
  }

  // ========== SECURE STORAGE (Sensitive Data) ==========

  // Token management
  Future<void> saveToken(String token) async {
    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.write(key: 'auth_token', value: token);
    } else {
      await _prefs.setString('auth_token', token);
    }
  }

  Future<String?> getToken() async {
    if (!kIsWeb && _secureStorage != null) {
      return await _secureStorage!.read(key: 'auth_token');
    }
    return _prefs.getString('auth_token');
  }

  Future<void> deleteToken() async {
    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.delete(key: 'auth_token');
    } else {
      await _prefs.remove('auth_token');
    }
  }

  // PIN management
  Future<void> savePin(String pin) async {
    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.write(key: 'transaction_pin', value: pin);
    } else {
      await _prefs.setString('transaction_pin', pin);
    }
  }

  Future<String?> getPin() async {
    if (!kIsWeb && _secureStorage != null) {
      return await _secureStorage!.read(key: 'transaction_pin');
    }
    return _prefs.getString('transaction_pin');
  }

  Future<bool> hasPin() async {
    String? pin = await getPin();
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    String? savedPin = await getPin();
    return savedPin == pin;
  }

  // ========== REGULAR STORAGE (Non-Sensitive Data) ==========

  // User data
  Future<void> saveUser(User user) async {
    await _prefs.setString('user', jsonEncode(user.toJson()));
  }

  User? getUser() {
    String? userStr = _prefs.getString('user');
    if (userStr != null) {
      return User.fromJson(jsonDecode(userStr));
    }
    return null;
  }

  Future<void> updateUserBalance(double balance) async {
    User? user = getUser();
    if (user != null) {
      await saveUser(user.copyWith(balance: balance));
    }
  }

  // Theme preference
  Future<void> saveThemeMode(bool isDark) async {
    await _prefs.setBool('is_dark_mode', isDark);
  }

  bool getThemeMode() {
    return _prefs.getBool('is_dark_mode') ?? false;
  }

  // Biometric preference
  Future<void> saveBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabled, enabled);
  }

  bool getBiometricEnabled() {
    return _prefs.getBool(_biometricEnabled) ?? false;
  }

  // First launch
  Future<void> setFirstLaunch(bool isFirst) async {
    await _prefs.setBool('first_launch', isFirst);
  }

  bool isFirstLaunch() {
    return _prefs.getBool('first_launch') ?? true;
  }

  // Remember me
  Future<void> saveRememberMe(bool remember) async {
    await _prefs.setBool('remember_me', remember);
  }

  bool getRememberMe() {
    return _prefs.getBool('remember_me') ?? false;
  }

  // Save last username for remember me
  Future<void> saveLastUsername(String username) async {
    await _prefs.setString('last_username', username);
  }

  String? getLastUsername() {
    return _prefs.getString('last_username');
  }

  // ========== NOTIFICATION PREFERENCES ==========

  bool getNotificationPreference(String type) {
    switch (type) {
      case 'transactions':
        return _prefs.getBool(_notificationTransactions) ?? true;
      case 'wallet':
        return _prefs.getBool(_notificationWallet) ?? true;
      case 'referrals':
        return _prefs.getBool(_notificationReferrals) ?? true;
      case 'promotional':
        return _prefs.getBool(_notificationPromotional) ?? false;
      default:
        return true;
    }
  }

  Future<void> saveNotificationPreference(String type, bool value) async {
    String key;
    switch (type) {
      case 'transactions':
        key = _notificationTransactions;
        break;
      case 'wallet':
        key = _notificationWallet;
        break;
      case 'referrals':
        key = _notificationReferrals;
        break;
      case 'promotional':
        key = _notificationPromotional;
        break;
      default:
        return;
    }
    await _prefs.setBool(key, value);
  }

  // ========== BENEFICIARIES (Client-side only) ==========

  Future<void> saveBeneficiaries(Map<String, dynamic> beneficiaries) async {
    await _prefs.setString('beneficiaries', jsonEncode(beneficiaries));
  }

  Map<String, dynamic> getBeneficiaries() {
    String? data = _prefs.getString('beneficiaries');
    if (data != null) {
      return jsonDecode(data);
    }
    return {};
  }

  // ========== CLEAR DATA ==========

  // Logout - clear all data
  Future<void> clearAll() async {
    if (!kIsWeb && _secureStorage != null) {
      await _secureStorage!.deleteAll();
    }
    await _prefs.clear();
  }

  // Clear only auth data (keep preferences)
  Future<void> clearAuth() async {
    await deleteToken();
    await _prefs.remove('user');
  }
}
