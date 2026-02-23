import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart';
import '../services/cache_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _networkFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  // Auth provider reference for API calls
  AuthProvider? _authProvider;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  // Getters
  List<Transaction> get transactions => _filteredTransactions;
  List<Transaction> get allTransactions => _transactions;
  List<Transaction> get recentTransactions =>
      _filteredTransactions.take(5).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filter getters
  String get typeFilter => _typeFilter;
  String get statusFilter => _statusFilter;
  String get networkFilter => _networkFilter;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get searchQuery => _searchQuery;

  bool get hasActiveFilters =>
      _typeFilter != 'all' ||
      _statusFilter != 'all' ||
      _networkFilter != 'all' ||
      _startDate != null ||
      _endDate != null ||
      _searchQuery.isNotEmpty;

  void addTransaction(Transaction transaction) {
    _transactions.insert(0, transaction);
    _applyFilters();
    CacheService.cacheTransactions(_transactions);
    notifyListeners();
  }

  Future<bool> fetchTransactions() async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Show cached data immediately while fetching
      final cached = CacheService.getCachedTransactions();
      if (cached != null && _transactions.isEmpty) {
        _transactions = cached;
        _applyFilters();
        notifyListeners();
      }

      // Call real API
      final result = await _authProvider?.authService.api.getTransactions();

      if (result != null && result.success && result.data != null) {
        _transactions = result.data!.transactions;
        await CacheService.cacheTransactions(_transactions);
        _error = null;
      } else {
        // If API fails but we have cache, keep showing cache silently
        if (_transactions.isEmpty) {
          _error = result?.error ?? 'Failed to load transactions';
        }
      }

      _isLoading = false;
      _applyFilters();
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (_transactions.isEmpty) {
        _error = e.toString();
      }
      notifyListeners();
      return false;
    }
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  void setNetworkFilter(String network) {
    _networkFilter = network;
    _applyFilters();
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _typeFilter = 'all';
    _statusFilter = 'all';
    _networkFilter = 'all';
    _startDate = null;
    _endDate = null;
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTransactions = _transactions.where((transaction) {
      // Type filter
      if (_typeFilter != 'all' && transaction.type.name != _typeFilter) {
        return false;
      }

      // Status filter
      if (_statusFilter != 'all' && transaction.status.name != _statusFilter) {
        return false;
      }

      // Network filter — partial match since API networks can be "MTN_DATA SHARE"
      if (_networkFilter != 'all' &&
          !transaction.network.toLowerCase().contains(
            _networkFilter.toLowerCase(),
          )) {
        return false;
      }

      // Date range filter
      if (_startDate != null) {
        final startOfDay = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        if (transaction.createdAt.isBefore(startOfDay)) return false;
      }

      if (_endDate != null) {
        final endOfDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );
        if (transaction.createdAt.isAfter(endOfDay)) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final beneficiary = transaction.beneficiary?.toLowerCase() ?? '';
        final reference = transaction.reference?.toLowerCase() ?? '';
        final network = transaction.network.toLowerCase();
        final type = transaction.typeDisplayName.toLowerCase();

        if (!beneficiary.contains(query) &&
            !reference.contains(query) &&
            !network.contains(query) &&
            !type.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void loadFromCache(List<Transaction> cached) {
    _transactions = cached;
    _applyFilters();
    notifyListeners();
  }

  void clearTransactions() {
    _transactions.clear();
    _filteredTransactions.clear();
    _error = null;
    notifyListeners();
  }
}
