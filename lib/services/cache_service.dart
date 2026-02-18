import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/data_plan_model.dart';
import '../models/cable_plan_model.dart';
import '../models/user_model.dart';

class CacheService {
  static SharedPreferences? _prefs;

  // Cache Keys
  static const String _walletBalance = 'cache_wallet_balance';
  static const String _walletBalanceTime = 'cache_wallet_balance_time';
  static const String _transactions = 'cache_transactions';
  static const String _transactionsTime = 'cache_transactions_time';
  static const String _dataPlans = 'cache_data_plans';
  static const String _dataPlansTime = 'cache_data_plans_time';
  static const String _userProfile = 'cache_user_profile';
  static const String _userProfileTime = 'cache_user_profile_time';
  static const String _beneficiaries = 'cache_beneficiaries';
  static const String _beneficiariesTime = 'cache_beneficiaries_time';
  static const String _cablePlansPrefix = 'cache_cable_plans_';
  static const String _cablePlansTimePrefix = 'cache_cable_plans_time_';

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> _ensureInit() async {
    if (_prefs == null) await init();
  }

  // ─── Wallet Balance ────────────────────────────────────────────────────────

  static Future<void> cacheWalletBalance(double balance) async {
    await _ensureInit();
    await _prefs!.setDouble(_walletBalance, balance);
    await _prefs!.setString(
      _walletBalanceTime,
      DateTime.now().toIso8601String(),
    );
  }

  static double? getCachedWalletBalance() {
    return _prefs?.getDouble(_walletBalance);
  }

  static DateTime? getWalletBalanceTime() {
    final timeStr = _prefs?.getString(_walletBalanceTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // ─── Transactions ──────────────────────────────────────────────────────────

  static Future<void> cacheTransactions(List<Transaction> transactions) async {
    await _ensureInit();

    // Only cache last 100
    final toCache = transactions.take(100).toList();
    final jsonList = toCache.map((t) => t.toJson()).toList();

    await _prefs!.setString(_transactions, jsonEncode(jsonList));
    await _prefs!.setString(
      _transactionsTime,
      DateTime.now().toIso8601String(),
    );
  }

  static List<Transaction>? getCachedTransactions() {
    final jsonStr = _prefs?.getString(_transactions);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  static DateTime? getTransactionsTime() {
    final timeStr = _prefs?.getString(_transactionsTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // ─── Data Plans ────────────────────────────────────────────────────────────

  static Future<void> cacheDataPlans(
    String network,
    List<DataPlan> plans,
  ) async {
    await _ensureInit();

    final key = '${_dataPlans}_$network';
    final timeKey = '${_dataPlansTime}_$network';

    final jsonList = plans.map((p) => p.toJson()).toList();
    await _prefs!.setString(key, jsonEncode(jsonList));
    await _prefs!.setString(timeKey, DateTime.now().toIso8601String());
  }

  static List<DataPlan>? getCachedDataPlans(String network) {
    final key = '${_dataPlans}_$network';
    final jsonStr = _prefs?.getString(key);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map(
            (json) => DataPlan.fromJson(
              json,
              json['network'] ?? '',
              json['type'] ?? '',
            ),
          )
          .toList();
    } catch (e) {
      return null;
    }
  }

  static DateTime? getDataPlansTime(String network) {
    final timeKey = '${_dataPlansTime}_$network';
    final timeStr = _prefs?.getString(timeKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // ─── User Profile ──────────────────────────────────────────────────────────

  static Future<void> cacheUserProfile(User user) async {
    await _ensureInit();
    await _prefs!.setString(_userProfile, jsonEncode(user.toJson()));
    await _prefs!.setString(_userProfileTime, DateTime.now().toIso8601String());
  }

  static User? getCachedUserProfile() {
    final jsonStr = _prefs?.getString(_userProfile);
    if (jsonStr == null) return null;

    try {
      return User.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  static DateTime? getUserProfileTime() {
    final timeStr = _prefs?.getString(_userProfileTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // ─── Cable Plans ──────────────────────────────────────────────────────────

  static Future<void> cacheCablePlans(
    String provider,
    List<CablePlan> plans,
  ) async {
    await _ensureInit();
    final jsonList = plans.map((p) => p.toJson()).toList();
    await _prefs!.setString(
      '$_cablePlansPrefix$provider',
      jsonEncode(jsonList),
    );
    await _prefs!.setString(
      '$_cablePlansTimePrefix$provider',
      DateTime.now().toIso8601String(),
    );
  }

  static List<CablePlan>? getCachedCablePlans(String provider) {
    final jsonStr = _prefs?.getString('$_cablePlansPrefix$provider');
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map(
            (json) =>
                CablePlan.fromJson(Map<String, dynamic>.from(json), provider),
          )
          .toList();
    } catch (e) {
      return null;
    }
  }

  // ─── Beneficiaries ─────────────────────────────────────────────────────────

  static Future<void> cacheBeneficiaries(
    Map<String, dynamic> beneficiaries,
  ) async {
    await _ensureInit();
    await _prefs!.setString(_beneficiaries, jsonEncode(beneficiaries));
    await _prefs!.setString(
      _beneficiariesTime,
      DateTime.now().toIso8601String(),
    );
  }

  static Map<String, dynamic>? getCachedBeneficiaries() {
    final jsonStr = _prefs?.getString(_beneficiaries);
    if (jsonStr == null) return null;

    try {
      return Map<String, dynamic>.from(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  // ─── Utilities ─────────────────────────────────────────────────────────────

  /// Human-readable "last updated" string
  static String getLastUpdatedText(DateTime? time) {
    if (time == null) return 'Never synced';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago';
    }
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }

  /// Check if cache is stale (older than threshold)
  static bool isCacheStale(
    DateTime? time, {
    Duration threshold = const Duration(minutes: 30),
  }) {
    if (time == null) return true;
    return DateTime.now().difference(time) > threshold;
  }

  /// Clear all cached data
  static Future<void> clearAll() async {
    await _ensureInit();
    final keys = [
      _walletBalance,
      _walletBalanceTime,
      _transactions,
      _transactionsTime,
      _dataPlans,
      _dataPlansTime,
      _userProfile,
      _userProfileTime,
      _beneficiaries,
      _beneficiariesTime,
    ];
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}
