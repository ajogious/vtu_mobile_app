import 'package:flutter/foundation.dart';

class ReferralProvider with ChangeNotifier {
  double _totalEarnings = 0;
  double _availableBalance = 0;
  int _totalReferrals = 0;
  List<Map<String, dynamic>> _earnings = [];
  List<Map<String, dynamic>> _filteredEarnings = [];
  bool _isLoading = false;

  // Getters
  double get totalEarnings => _totalEarnings;
  double get availableBalance => _availableBalance;
  int get totalReferrals => _totalReferrals;
  List<Map<String, dynamic>> get earnings => _earnings;
  List<Map<String, dynamic>> get filteredEarnings => _filteredEarnings;
  bool get isLoading => _isLoading;

  Future<void> fetchReferralData() async {
    _isLoading = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Mock data - replace with actual API call
    _totalEarnings = 1500;
    _availableBalance = 800;
    _totalReferrals = 15;

    _earnings = [
      {
        'amount': 100.0,
        'source': 'Referral: John Doe',
        'date': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'amount': 100.0,
        'source': 'Referral: Jane Smith',
        'date': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'amount': 100.0,
        'source': 'Referral: Mike Johnson',
        'date': DateTime.now().subtract(const Duration(days: 7)),
      },
      {
        'amount': 100.0,
        'source': 'Referral: Sarah Williams',
        'date': DateTime.now().subtract(const Duration(days: 10)),
      },
      {
        'amount': 100.0,
        'source': 'Referral: David Brown',
        'date': DateTime.now().subtract(const Duration(days: 15)),
      },
    ];

    _filteredEarnings = List.from(_earnings);

    _isLoading = false;
    notifyListeners();
  }

  void filterByDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      _filteredEarnings = List.from(_earnings);
    } else {
      _filteredEarnings = _earnings.where((earning) {
        final date = earning['date'] as DateTime;

        if (start != null && date.isBefore(start)) return false;
        if (end != null && date.isAfter(end)) return false;

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

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    _availableBalance -= amount;

    _isLoading = false;
    notifyListeners();

    return true;
  }

  void addEarning(double amount, String source) {
    _earnings.insert(0, {
      'amount': amount,
      'source': source,
      'date': DateTime.now(),
    });

    _totalEarnings += amount;
    _availableBalance += amount;
    _totalReferrals++;

    _filteredEarnings = List.from(_earnings);
    notifyListeners();
  }
}
