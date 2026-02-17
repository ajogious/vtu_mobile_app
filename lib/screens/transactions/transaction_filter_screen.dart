import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/custom_button.dart';

class TransactionFilterScreen extends StatefulWidget {
  const TransactionFilterScreen({super.key});

  @override
  State<TransactionFilterScreen> createState() =>
      _TransactionFilterScreenState();
}

class _TransactionFilterScreenState extends State<TransactionFilterScreen> {
  late String _selectedType;
  late String _selectedStatus;
  late String _selectedNetwork;
  late String _selectedDateRange;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final List<String> _types = [
    'all',
    'airtime',
    'data',
    'cable',
    'electricity',
    'examPin',
    'dataCard',
    'walletFunding',
  ];

  final List<String> _statuses = ['all', 'success', 'pending', 'failed'];

  final List<String> _networks = [
    'all',
    'MTN',
    'GLO',
    'AIRTEL',
    '9MOBILE',
    'DSTV',
    'GOTV',
    'STARTIMES',
    'EKEDC',
    'IKEDC',
    'AEDC',
    'PHED',
    'WAEC',
    'NECO',
    'NABTEB',
  ];

  final List<String> _dateRanges = [
    'all',
    'today',
    'last7days',
    'last30days',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _selectedType = provider.typeFilter;
    _selectedStatus = provider.statusFilter;
    _selectedNetwork = provider.networkFilter;
    _selectedDateRange = _getDateRangeKey(provider);
    _customStartDate = provider.startDate;
    _customEndDate = provider.endDate;
  }

  String _getDateRangeKey(TransactionProvider provider) {
    if (provider.startDate == null && provider.endDate == null) {
      return 'all';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (provider.startDate != null) {
      final start = DateTime(
        provider.startDate!.year,
        provider.startDate!.month,
        provider.startDate!.day,
      );

      if (start == today && provider.endDate == null) {
        return 'today';
      }

      final last7 = today.subtract(const Duration(days: 6));
      if (start == last7 && provider.endDate == null) {
        return 'last7days';
      }

      final last30 = today.subtract(const Duration(days: 29));
      if (start == last30 && provider.endDate == null) {
        return 'last30days';
      }
    }

    return 'custom';
  }

  void _applyFilters() {
    final provider = context.read<TransactionProvider>();

    // Apply type filter
    provider.setTypeFilter(_selectedType);

    // Apply status filter
    provider.setStatusFilter(_selectedStatus);

    // Apply network filter
    provider.setNetworkFilter(_selectedNetwork);

    // Apply date filter
    DateTime? startDate;
    DateTime? endDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedDateRange) {
      case 'today':
        startDate = today;
        break;
      case 'last7days':
        startDate = today.subtract(const Duration(days: 6));
        break;
      case 'last30days':
        startDate = today.subtract(const Duration(days: 29));
        break;
      case 'custom':
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
      default:
        startDate = null;
        endDate = null;
    }

    provider.setDateRange(startDate, endDate);

    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _selectedType = 'all';
      _selectedStatus = 'all';
      _selectedNetwork = 'all';
      _selectedDateRange = 'all';
      _customStartDate = null;
      _customEndDate = null;
    });
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? _customStartDate : _customEndDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartDate = picked;
        } else {
          _customEndDate = picked;
        }
        _selectedDateRange = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          const Divider(),

          // Filters
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range
                  _buildSectionTitle('Date Range'),
                  const SizedBox(height: 8),
                  ..._dateRanges.map((range) {
                    return RadioListTile<String>(
                      title: Text(_getDateRangeLabel(range)),
                      value: range,
                      groupValue: _selectedDateRange,
                      onChanged: (value) {
                        setState(() {
                          _selectedDateRange = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }),

                  // Custom date picker
                  if (_selectedDateRange == 'custom') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _customStartDate != null
                                  ? DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_customStartDate!)
                                  : 'Start Date',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(false),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _customEndDate != null
                                  ? DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_customEndDate!)
                                  : 'End Date',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Transaction Type
                  _buildSectionTitle('Transaction Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final isSelected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(_getTypeLabel(type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = type;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Status
                  _buildSectionTitle('Status'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _statuses.map((status) {
                      final isSelected = _selectedStatus == status;
                      return ChoiceChip(
                        label: Text(_getStatusLabel(status)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatus = status;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Network
                  _buildSectionTitle('Network/Provider'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _networks.map((network) {
                      final isSelected = _selectedNetwork == network;
                      return ChoiceChip(
                        label: Text(
                          network == 'all' ? 'All Networks' : network,
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedNetwork = network;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomButton(
              text: 'Apply Filters',
              onPressed: _applyFilters,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  String _getDateRangeLabel(String range) {
    switch (range) {
      case 'all':
        return 'All Time';
      case 'today':
        return 'Today';
      case 'last7days':
        return 'Last 7 Days';
      case 'last30days':
        return 'Last 30 Days';
      case 'custom':
        return 'Custom Range';
      default:
        return range;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'all':
        return 'All Types';
      case 'airtime':
        return 'Airtime';
      case 'data':
        return 'Data';
      case 'cable':
        return 'Cable TV';
      case 'electricity':
        return 'Electricity';
      case 'examPin':
        return 'Exam Pin';
      case 'dataCard':
        return 'Data Card';
      case 'walletFunding':
        return 'Wallet Funding';
      default:
        return type;
    }
  }

  String _getStatusLabel(String status) {
    if (status == 'all') return 'All Status';
    return status[0].toUpperCase() + status.substring(1);
  }
}
