import 'package:flutter/foundation.dart';
import '../models/referral_model.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';

class ReferralProvider with ChangeNotifier {
  double _totalEarnings = 0;
  double _availableBalance = 0;
  int _totalReferrals = 0;
  List<ReferralEarning> _earnings = [];
  List<ReferralEarning> _filteredEarnings = [];

  /// True only on the very first load when there is no cache yet.
  bool _isLoading = false;

  /// True when a background refresh is in progress (cache data is visible).
  bool _isRefreshing = false;

  String? _error;

  AuthProvider? _authProvider;
  final _storage = StorageService();

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  // Getters
  double get totalEarnings => _totalEarnings;
  double get availableBalance => _availableBalance;
  int get totalReferrals => _totalReferrals;
  List<ReferralEarning> get earnings => _earnings;
  List<ReferralEarning> get filteredEarnings => _filteredEarnings;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  /// Load referral data with a cache-first strategy:
  /// 1. Immediately show any cached data (instant, no spinner).
  /// 2. Fetch fresh data from the API in the background.
  /// 3. Update the UI when the API responds.
  Future<void> fetchReferralData() async {
    _error = null;

    // Step 1: Show cached data right away (if available).
    final cached = _storage.getReferralCache();
    if (cached != null) {
      _applyData(cached);
      _isRefreshing = true; // Background refresh indicator
      notifyListeners();
    } else {
      // No cache yet — show full loading spinner.
      _isLoading = true;
      notifyListeners();
    }

    // Step 2: Fetch from API (single call — stats AND history in one request).
    try {
      final result = await _authProvider?.authService.api.getReferralStats();

      if (result != null && result.success && result.data != null) {
        // Also fetch history (same endpoint, but we keep them separate for
        // cleaner provider API — both calls are fast since they share the endpoint).
        final historyResult = await _authProvider?.authService.api
            .getReferralHistory();

        final stats = result.data!;
        _totalEarnings = stats.totalEarnings;
        _availableBalance = stats.availableBalance;
        _totalReferrals = stats.totalReferrals;

        if (historyResult != null &&
            historyResult.success &&
            historyResult.data != null) {
          _earnings = historyResult.data!;
          _filteredEarnings = List.from(_earnings);
        }

        // Persist to cache so next open is instant.
        await _storage.saveReferralCache({
          'totalEarnings': _totalEarnings,
          'availableBalance': _availableBalance,
          'totalReferrals': _totalReferrals,
          'earnings': _earnings
              .map(
                (e) => {
                  'id': e.id,
                  'amount': e.amount,
                  'source': e.source,
                  'transactionId': e.transactionId,
                  'createdAt': e.createdAt.toIso8601String(),
                },
              )
              .toList(),
        });
      } else {
        // Only surface the error if we have no cached data to show.
        if (cached == null) {
          _error = result?.error ?? 'Failed to load referral data';
        }
      }
    } catch (e) {
      if (cached == null) {
        _error = e.toString();
      }
    }

    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  /// Apply a cached data map to the provider state.
  void _applyData(Map<String, dynamic> data) {
    _totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0;
    _availableBalance = (data['availableBalance'] as num?)?.toDouble() ?? 0;
    _totalReferrals = (data['totalReferrals'] as num?)?.toInt() ?? 0;

    final earningsList = data['earnings'] as List? ?? [];
    _earnings = earningsList
        .map(
          (e) => ReferralEarning(
            id: e['id']?.toString() ?? '',
            amount: (e['amount'] as num?)?.toDouble() ?? 0,
            source: e['source']?.toString() ?? '',
            transactionId: e['transactionId']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now(),
          ),
        )
        .toList();
    _filteredEarnings = List.from(_earnings);
  }

  void filterByDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      _filteredEarnings = List.from(_earnings);
    } else {
      _filteredEarnings = _earnings.where((earning) {
        if (start != null && earning.createdAt.isBefore(start)) return false;
        if (end != null && earning.createdAt.isAfter(end)) return false;
        return true;
      }).toList();
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> withdrawEarnings(
    double amount,
    String pincode,
  ) async {
    if (amount > _availableBalance) {
      _error = 'Insufficient balance';
      return null;
    }
    if (amount < 1) {
      _error = 'Minimum withdrawal is ₦1';
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authProvider?.authService.api
          .withdrawReferralEarnings(amount: amount, pincode: pincode);

      if (result != null && result.success && result.data != null) {
        // Use the exact commission_balance from the server if provided
        if (result.data!['commission_balance'] != null) {
          _availableBalance = (result.data!['commission_balance'] as num)
              .toDouble();
        } else {
          _availableBalance -= amount;
        }

        // Invalidate cache so next open fetches fresh data
        await _storage.clearReferralCache();

        _isLoading = false;
        notifyListeners();
        return result.data;
      } else {
        _error = result?.error ?? 'Withdrawal failed';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }
}
