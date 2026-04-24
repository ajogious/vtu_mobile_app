// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/airtime_network_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/cache_service.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_purchase_blocker.dart';
import '../widgets/cached_data_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry.dart';
import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../models/data_plan_model.dart';
import '../../models/transaction_model.dart';
import 'data_success_screen.dart';

class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});

  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedNetwork;
  String? _selectedDataType;
  DataPlan? _selectedPlan;
  bool _saveBeneficiary = false;
  final bool _isLoadingPlans = false;
  bool _isLoadingNetworks = true;
  bool _isProcessing = false;
  String? _loadPlansError;
  bool _plansFromCache = false;

  List<AirtimeNetwork> _airtimeNetworks = [];
  List<DataPlan> _allNetworkPlans = []; // all plans across all networks
  List<DataPlan> _allPlans = []; // plans for the selected network
  List<DataPlan> _filteredPlans = [];
  List<DataPlan> _searchedPlans = [];
  List<String> _dataTypes = [];
  List<Map<String, String>> _beneficiaries = [];
  List<Transaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    _loadRecentTransactions();
    _loadAllDataPlans();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Load ALL plans from the data API, extract network names dynamically,
  // and store plans locally for client-side filtering.
  Future<void> _loadAllDataPlans() async {
    final isOnline = context.read<NetworkProvider>().isOnline;

    if (!isOnline) {
      // Try to restore networks from any cached network's plans
      final fallbackNetworks = ['MTN', 'GLO', 'AIRTEL', '9MOBILE'];
      final List<DataPlan> cached = [];
      for (final n in fallbackNetworks) {
        final plans = CacheService.getCachedDataPlans(n);
        if (plans != null) cached.addAll(plans);
      }
      if (cached.isNotEmpty) {
        final networks = cached.map((p) => p.network).toSet().toList();
        setState(() {
          _allNetworkPlans = cached;
          _airtimeNetworks = networks
              .map((n) => AirtimeNetwork(network: n, serviceKey: ''))
              .toList();
          _isLoadingNetworks = false;
        });
      } else {
        if (mounted) {
          UiHelpers.showSnackBar(
            context,
            'No internet and no cached plans available',
            isError: true,
          );
        }
        setState(() => _isLoadingNetworks = false);
      }
      return;
    }

    // Fetch ALL plans (no network filter) to derive available networks
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getDataPlans();

    if (!mounted) return;

    if (result.success && result.data != null && result.data!.isNotEmpty) {
      final plans = result.data!;
      // Extract unique, ordered network names from the response
      final networks = plans.map((p) => p.network).toSet().toList();

      // Cache plans per-network for offline use
      for (final network in networks) {
        final netPlans = plans.where((p) => p.network == network).toList();
        await CacheService.cacheDataPlans(network, netPlans);
      }

      if (!mounted) return;
      setState(() {
        _allNetworkPlans = plans;
        _airtimeNetworks = networks
            .map((n) => AirtimeNetwork(network: n, serviceKey: ''))
            .toList();
        _isLoadingNetworks = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _isLoadingNetworks = false);
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to load data plans',
        isError: true,
      );
    }
  }

  void _loadBeneficiaries() {
    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();

    if (beneficiaries['data'] != null) {
      setState(() {
        _beneficiaries = List<Map<String, String>>.from(
          beneficiaries['data'].map((b) => Map<String, String>.from(b)),
        );
      });
    }
  }

  void _loadRecentTransactions() {
    // FIX: use allTransactions (unfiltered) so recent purchases always show
    final transactions = context
        .read<TransactionProvider>()
        .allTransactions
        .where((t) => t.type == TransactionType.data)
        .take(5)
        .toList();

    setState(() {
      _recentTransactions = transactions;
    });
  }

  Future<void> _saveBeneficiaryToStorage() async {
    if (!_saveBeneficiary || _phoneController.text.trim().isEmpty) return;

    final phone = _phoneController.text.trim();
    final network = _selectedNetwork ?? '';
    final dataType = _selectedDataType ?? '';

    final exists = _beneficiaries.any((b) => b['phone'] == phone);
    if (exists) return;

    _beneficiaries.insert(0, {
      'phone': phone,
      'network': network,
      'data_type': dataType,
    });

    if (_beneficiaries.length > 10) {
      _beneficiaries = _beneficiaries.sublist(0, 10);
    }

    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();
    beneficiaries['data'] = _beneficiaries;
    await storage.saveBeneficiaries(beneficiaries);
  }

  Future<void> _pickContact() async {
    try {
      PermissionStatus status = await Permission.contacts.status;

      if (status.isDenied) {
        status = await Permission.contacts.request();
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;

        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Contact permission is required to pick a phone number. '
              'Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        return;
      }

      if (!status.isGranted) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Contact permission is required to pick a number',
          isError: true,
        );
        return;
      }

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
        withPhoto: false,
      );

      if (fullContact == null) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Could not load contact details',
          isError: true,
        );
        return;
      }

      if (fullContact.phones.isEmpty) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Selected contact has no phone number',
          isError: true,
        );
        return;
      }

      String phone = fullContact.phones.first.number;
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

      if (phone.startsWith('+234')) {
        phone = '0${phone.substring(4)}';
      } else if (phone.startsWith('234')) {
        phone = '0${phone.substring(3)}';
      }

      if (!phone.startsWith('0') && phone.length >= 10) {
        phone = '0$phone';
      }

      if (phone.length > 11) {
        phone = phone.substring(0, 11);
      }

      if (mounted) {
        setState(() {
          _phoneController.text = phone;
        });
        UiHelpers.showSnackBar(context, 'Contact added successfully');
      }
    } on Exception catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to pick contact';
      if (e.toString().contains('PlatformException')) {
        errorMessage = 'Error accessing contacts. Please try again.';
      } else if (e.toString().contains('MissingPluginException')) {
        errorMessage =
            'Contact plugin not properly installed. Please restart the app.';
      }

      UiHelpers.showSnackBar(context, errorMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      UiHelpers.showSnackBar(
        context,
        'An unexpected error occurred',
        isError: true,
      );
    }
  }

  void _onNetworkSelected(String network) {
    setState(() {
      _selectedNetwork = network;
      _selectedDataType = null;
      _selectedPlan = null;
      _loadPlansError = null;
      _searchController.clear();
    });

    // Filter from already-loaded plans — no second API call needed
    _applyNetworkFilter(network);
  }

  void _applyNetworkFilter(String network) {
    final plans = _allNetworkPlans.where((p) => p.network == network).toList();

    final types = plans.map((p) => p.type).toSet().toList();

    setState(() {
      _plansFromCache = false;
      _allPlans = plans;
      _dataTypes = types;
      _filteredPlans = [];
      _searchedPlans = [];
      if (types.isNotEmpty) {
        _selectedDataType = types.first;
        _filterPlansByType(types.first);
      }
    });
  }

  void _filterPlansByType(String type) {
    setState(() {
      _selectedDataType = type;
      _selectedPlan = null;
      _filteredPlans = _allPlans.where((plan) => plan.type == type).toList();
      _searchedPlans = _filteredPlans;
      _searchController.clear();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _searchedPlans = _filteredPlans;
      } else {
        _searchedPlans = _filteredPlans.where((plan) {
          return plan.name.toLowerCase().contains(query) ||
              plan.price.toString().contains(query) ||
              plan.validity.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectBeneficiary(Map<String, String> beneficiary) {
    setState(() {
      _phoneController.text = beneficiary['phone'] ?? '';
      _selectedNetwork = beneficiary['network'];
    });

    if (_selectedNetwork != null) {
      _applyNetworkFilter(_selectedNetwork!);
      final dataType = beneficiary['data_type'];
      if (dataType != null && _dataTypes.contains(dataType)) {
        _filterPlansByType(dataType);
      }
    }
  }

  void _selectFromTransaction(Transaction transaction) {
    setState(() {
      _phoneController.text = transaction.beneficiary ?? '';
      _selectedNetwork = transaction.network;
    });

    if (_selectedNetwork != null) {
      _applyNetworkFilter(_selectedNetwork!);
      final dataType = transaction.metadata?['data_type'];
      if (dataType != null && _dataTypes.contains(dataType)) {
        _filterPlansByType(dataType);
        // Match by plan id stored in metadata
        final planId = transaction.metadata?['plan_id'];
        if (planId != null && _searchedPlans.isNotEmpty) {
          final plan = _searchedPlans.firstWhere(
            (p) => p.id == planId,
            orElse: () => _searchedPlans.first,
          );
          setState(() => _selectedPlan = plan);
        }
      }
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedNetwork == null) {
      UiHelpers.showSnackBar(context, 'Please select a network', isError: true);
      return;
    }

    if (_selectedPlan == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select a data plan',
        isError: true,
      );
      return;
    }

    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final balance = context.read<WalletProvider>().balance;
    if (balance < _selectedPlan!.price) {
      ErrorHandler.handleInsufficientBalance(
        context,
        balance,
        _selectedPlan!.price,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmRow('Network', _selectedNetwork!),
              _buildConfirmRow('Data Type', _selectedDataType!),
              _buildConfirmRow('Plan', _selectedPlan!.name),
              _buildConfirmRow('Validity', _selectedPlan!.validity),
              _buildConfirmRow('Phone Number', _phoneController.text.trim()),
              const Divider(height: 24),
              _buildConfirmRow(
                'Amount',
                '₦${NumberFormat('#,##0.00').format(_selectedPlan!.price)}',
                isBold: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _buyData();
    }
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyData() async {
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final phone = _phoneController.text.trim();
    final amount = _selectedPlan!.price;

    final serverPinSet = context.read<AuthProvider>().user?.pinSet == true;
    final verifiedPin = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle: 'Authorize purchase of ${_selectedPlan!.name}',
      serverPinSet: serverPinSet,
    );

    if (verifiedPin == null) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    if (amount >= 10000) {
      final reAuthenticated = await requireReAuthentication(
        context,
        action: 'authorize this large transaction',
      );

      if (!reAuthenticated) {
        UiHelpers.showSnackBar(
          context,
          'Re-authentication failed',
          isError: true,
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    final authService = context.read<AuthProvider>().authService;

    final result = await authService.api.buyData(
      network: _selectedNetwork!, // "MTN" ✓
      dataType: _selectedDataType!, // "DATA SHARE" ✓
      dataPlan: _selectedPlan!.id, // "8" → parsed to int in API layer ✓
      number: phone,
      pincode: verifiedPin,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.success && result.data != null) {
      await _saveBeneficiaryToStorage();

      final walletProvider = context.read<WalletProvider>();
      final balanceBefore = walletProvider.balance;
      walletProvider.deductBalance(amount);

      final transaction = Transaction(
        id: result.data!['transaction_id'] ?? '',
        type: TransactionType.data,
        network: _selectedNetwork!,
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: phone,
        reference: result.data!['transaction_id'] ?? '',
        balanceBefore: balanceBefore,
        balanceAfter: balanceBefore - amount,
        metadata: {
          'data_type': _selectedDataType!,
          'bundle': _selectedPlan!.name,
          'validity': _selectedPlan!.validity,
          // FIX: store plan id so repeat purchases can restore selection exactly
          'plan_id': _selectedPlan!.id,
        },
      );

      context.read<TransactionProvider>().addTransaction(transaction);

      await NotificationService.transactionSuccess(transaction);

      final newBalance = context.read<WalletProvider>().balance;
      if (newBalance < 500) {
        await NotificationService.lowBalance(newBalance);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DataSuccessScreen(
            transaction: transaction,
            dataPlan: _selectedPlan!,
            providerMessage: result.data!['message']?.toString(),
          ),
        ),
      );
    } else {
      // Wait one frame so LoadingOverlay finishes rebuilding before showing UI
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      final errorMsg = result.error ?? 'Purchase failed';
      // Show as SnackBar first — ScaffoldMessenger works reliably after async gaps
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkProvider = context.watch<NetworkProvider>();

    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Data'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing data purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  _isLoadingNetworks
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : NetworkSelector(
                          selectedNetwork: _selectedNetwork,
                          networks: _airtimeNetworks,
                          showDiscount: false,
                          onNetworkSelected: (airtimeNetwork) {
                            _onNetworkSelected(airtimeNetwork.network);
                          },
                        ),
                  const SizedBox(height: 24),

                  // Phone Number with Contact Picker
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _phoneController,
                          labelText: 'Phone Number',
                          hintText: '08012345678',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: Validators.nigerianPhone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickContact,
                        icon: const Icon(Icons.contacts),
                        tooltip: 'Pick from contacts',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Data Type Selector
                  if (_selectedNetwork != null && _dataTypes.isNotEmpty) ...[
                    Text(
                      'Select Data Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dataTypes.map((type) {
                        final isSelected = _selectedDataType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) _filterPlansByType(type);
                          },
                          selectedColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Search Bar
                  if (_filteredPlans.isNotEmpty) ...[
                    CustomTextField(
                      controller: _searchController,
                      labelText: 'Search Plans',
                      hintText: 'Search by name, price, or validity',
                      prefixIcon: Icons.search,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Loading Plans
                  if (_isLoadingPlans)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  // Data Plans List
                  if (!_isLoadingPlans && _searchedPlans.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Data Plan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            if (_plansFromCache)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CachedDataBadge(
                                  cachedAt: _selectedNetwork != null
                                      ? CacheService.getDataPlansTime(
                                          _selectedNetwork!,
                                        )
                                      : null,
                                ),
                              ),
                            Text(
                              '${_searchedPlans.length} plan${_searchedPlans.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._searchedPlans.map((plan) => _buildPlanCard(plan)),
                    const SizedBox(height: 16),
                  ],

                  // Error loading plans
                  if (_loadPlansError != null && !_isLoadingPlans)
                    ErrorRetry(
                      message: _loadPlansError!,
                      onRetry: () {
                        setState(() => _loadPlansError = null);
                        if (_selectedNetwork != null) {
                          _loadAllDataPlans();
                        }
                      },
                    ),

                  // No plans message
                  if (!_isLoadingPlans &&
                      _loadPlansError == null &&
                      _selectedNetwork != null &&
                      _searchedPlans.isEmpty &&
                      _selectedDataType != null)
                    EmptyState(
                      icon: Icons.inbox,
                      title: _searchController.text.isNotEmpty
                          ? 'No plans found'
                          : 'No plans available',
                      message: _searchController.text.isNotEmpty
                          ? 'Try a different search term'
                          : 'No data plans are available for this selection',
                      actionText: _searchController.text.isNotEmpty
                          ? 'Clear search'
                          : null,
                      onAction: _searchController.text.isNotEmpty
                          ? () => setState(() => _searchController.clear())
                          : null,
                    ),

                  // Save Beneficiary
                  if (_selectedPlan != null)
                    CheckboxListTile(
                      value: _saveBeneficiary,
                      onChanged: (value) {
                        setState(() {
                          _saveBeneficiary = value ?? false;
                        });
                      },
                      title: const Text('Save as beneficiary'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                  // Buy Button
                  if (_selectedPlan != null) ...[
                    const SizedBox(height: 16),
                    OfflinePurchaseBlocker(
                      serviceName: 'data',
                      child: CustomButton(
                        text:
                            'Continue - ₦${NumberFormat('#,##0').format(_selectedPlan!.price)}',
                        onPressed: networkProvider.isOnline
                            ? _showConfirmationDialog
                            : null,
                        isLoading: _isProcessing,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Beneficiaries
                  if (_beneficiaries.isNotEmpty) ...[
                    Text(
                      'Beneficiaries',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 85,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _beneficiaries.length,
                        itemBuilder: (context, index) {
                          return _buildBeneficiaryCard(_beneficiaries[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recent Transactions
                  if (_recentTransactions.isNotEmpty) ...[
                    Text(
                      'Recent Purchases',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._recentTransactions.map(
                      (t) => _buildRecentTransactionCard(t),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(DataPlan plan) {
    // FIX: compare by plan.id not plan.name — names can duplicate across types
    final isSelected = _selectedPlan?.id == plan.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Radio<DataPlan>(
              value: plan,
              groupValue: _selectedPlan,
              onChanged: (value) => setState(() => _selectedPlan = value),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.validity,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '₦${NumberFormat('#,##0').format(plan.price)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(Map<String, String> beneficiary) {
    final phone = beneficiary['phone'] ?? '';
    final network = beneficiary['network'] ?? '';

    return GestureDetector(
      onTap: () => _selectBeneficiary(beneficiary),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(height: 6),
            Text(
              phone,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              network,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionCard(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.wifi, color: Colors.green),
        ),
        title: Text(transaction.beneficiary ?? ''),
        subtitle: Text(
          '${transaction.network} • ${transaction.metadata?['bundle'] ?? ''} • ₦${NumberFormat('#,##0').format(transaction.amount)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward, size: 20),
          onPressed: () => _selectFromTransaction(transaction),
        ),
      ),
    );
  }
}
