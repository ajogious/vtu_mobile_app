import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';

class TransactionProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = false;
  final bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  // Filters
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _networkFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  // Getters
  List<Transaction> get transactions => _filteredTransactions;
  List<Transaction> get allTransactions => _transactions;
  List<Transaction> get recentTransactions =>
      _filteredTransactions.take(5).toList();
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get totalCount => _filteredTransactions.length;

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
    notifyListeners();
  }

  Future<bool> fetchTransactions({
    int page = 1,
    int limit = 10,
    bool loadMore = false,
  }) async {
    if (_isLoading) return false;

    if (!loadMore) {
      _isLoading = true;
      _currentPage = 1;
      _error = null;
      notifyListeners();
    }

    try {
      // In real app, call API here
      // For now, transactions are added via addTransaction()

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate API call

      _isLoading = false;
      _applyFilters();
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _currentPage++;
    await fetchTransactions(page: _currentPage, loadMore: true);
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

      // Network filter
      if (_networkFilter != 'all' && transaction.network != _networkFilter) {
        return false;
      }

      // Date range filter
      if (_startDate != null) {
        final startOfDay = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        if (transaction.createdAt.isBefore(startOfDay)) {
          return false;
        }
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
        if (transaction.createdAt.isAfter(endOfDay)) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final beneficiary = transaction.beneficiary?.toLowerCase() ?? '';
        final reference = transaction.reference?.toLowerCase() ?? '';
        final network = transaction.network.toLowerCase();

        if (!beneficiary.contains(query) &&
            !reference.contains(query) &&
            !network.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void clearTransactions() {
    _transactions.clear();
    _filteredTransactions.clear();
    notifyListeners();
  }
}
