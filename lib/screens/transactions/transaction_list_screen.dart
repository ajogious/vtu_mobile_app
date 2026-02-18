import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/cache_service.dart';
import '../../utils/ui_helpers.dart';
import '../widgets/cached_data_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';
import 'transaction_filter_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    final isOnline = context.read<NetworkProvider>().isOnline;

    if (!isOnline) {
      // Serve from cache when offline
      final cached = CacheService.getCachedTransactions();
      if (cached != null) {
        context.read<TransactionProvider>().loadFromCache(cached);
      } else {
        UiHelpers.showSnackBar(
          context,
          'No internet. No cached data available.',
          isError: true,
        );
      }
      return;
    }

    await context.read<TransactionProvider>().fetchTransactions();
  }

  Future<void> _loadMore() async {
    await context.read<TransactionProvider>().loadMore();
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransactionFilterScreen(),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<TransactionProvider>().setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  context.read<TransactionProvider>().setSearchQuery(value);
                },
              )
            : const Text('Transactions'),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                Consumer<TransactionProvider>(
                  builder: (context, provider, _) {
                    if (provider.hasActiveFilters) {
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          // Loading state (first load)
          if (provider.isLoading && provider.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.error != null && provider.transactions.isEmpty) {
            return ErrorRetry(
              message: provider.error!,
              onRetry: _loadTransactions,
            );
          }

          // Empty state
          if (provider.transactions.isEmpty) {
            if (provider.hasActiveFilters) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'No Results Found',
                message: 'No transactions match your search or filters.',
                actionText: 'Clear Filters',
                onAction: () {
                  provider.clearFilters();
                  _searchController.clear();
                },
              );
            }

            return EmptyState(
              icon: Icons.receipt_long,
              title: 'No Transactions',
              message: 'Your transaction history will appear here.',
              actionText: 'Make a Purchase',
              onAction: () {
                Navigator.pop(context);
              },
            );
          }

          // Transaction list
          return RefreshIndicator(
            onRefresh: _loadTransactions,
            child: Column(
              children: [
                // Offline/cache banner — shown at the top of the list
                OfflineContentBanner(
                  cachedAt: CacheService.getTransactionsTime(),
                ),

                // Active filters chip
                if (provider.hasActiveFilters)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Icon(
                          Icons.filter_alt,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getActiveFiltersText(provider),
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            provider.clearFilters();
                            _searchController.clear();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),

                // Transaction count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${provider.totalCount} transaction${provider.totalCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        provider.transactions.length +
                        (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Load more indicator
                      if (index == provider.transactions.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final transaction = provider.transactions[index];
                      return TransactionCard(
                        transaction: transaction,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailScreen(
                                transaction: transaction,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getActiveFiltersText(TransactionProvider provider) {
    final filters = <String>[];

    if (provider.typeFilter != 'all') filters.add(provider.typeFilter);
    if (provider.statusFilter != 'all') filters.add(provider.statusFilter);
    if (provider.networkFilter != 'all') filters.add(provider.networkFilter);
    if (provider.startDate != null || provider.endDate != null) {
      filters.add('date range');
    }
    if (provider.searchQuery.isNotEmpty) filters.add('search');

    if (filters.isEmpty) return '';
    if (filters.length == 1) return 'Filtered by ${filters[0]}';
    return 'Filtered by ${filters.length} criteria';
  }
}
