import 'package:flutter/foundation.dart';
import '../models/referral_model.dart';
import '../providers/auth_provider.dart';

class ReferralProvider with ChangeNotifier {
  double _totalEarnings = 0;
  double _availableBalance = 0;
  int _totalReferrals = 0;
  List<ReferralEarning> _earnings = [];
  List<ReferralEarning> _filteredEarnings = [];
  bool _isLoading = false;
  String? _error;

  AuthProvider? _authProvider;

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
  String? get error => _error;

  Future<void> fetchReferralData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch stats and history from same endpoint
      final statsResult = await _authProvider?.authService.api
          .getReferralStats();
      final historyResult = await _authProvider?.authService.api
          .getReferralHistory();

      if (statsResult != null &&
          statsResult.success &&
          statsResult.data != null) {
        final stats = statsResult.data!;
        _totalEarnings = stats.totalEarnings;
        _availableBalance = stats.availableBalance;
        _totalReferrals = stats.totalReferrals;
      }

      if (historyResult != null &&
          historyResult.success &&
          historyResult.data != null) {
        _earnings = historyResult.data!;
        _filteredEarnings = List.from(_earnings);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
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

  Future<bool> withdrawEarnings(double amount) async {
    if (amount > _availableBalance) return false;
    if (amount < 500) return false;

    _isLoading = true;
    notifyListeners();

    // TODO: wire up real withdrawal endpoint when available
    await Future.delayed(const Duration(seconds: 2));

    _availableBalance -= amount;
    _isLoading = false;
    notifyListeners();

    return true;
  }
}
