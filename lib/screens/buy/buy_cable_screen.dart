import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/error_handler.dart';
import '../../services/storage_service.dart';
import '../../models/cable_plan_model.dart';
import '../../models/transaction_model.dart';
import 'cable_success_screen.dart';

class BuyCableScreen extends StatefulWidget {
  const BuyCableScreen({super.key});

  @override
  State<BuyCableScreen> createState() => _BuyCableScreenState();
}

class _BuyCableScreenState extends State<BuyCableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smartcardController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedProvider;
  String? _customerName;
  CablePlan? _selectedPlan;
  bool _saveBeneficiary = false;
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isLoadingPlans = false;
  bool _isProcessing = false;
  String? _loadPlansError;

  List<CablePlan> _allPlans = [];
  List<CablePlan> _searchedPlans = [];
  List<Map<String, String>> _beneficiaries = [];
  List<Transaction> _recentTransactions = [];

  final List<String> _providers = ['DSTV', 'GOTV', 'STARTIMES'];

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    _loadRecentTransactions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _smartcardController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadBeneficiaries() {
    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();

    if (beneficiaries['cable'] != null) {
      setState(() {
        _beneficiaries = List<Map<String, String>>.from(
          beneficiaries['cable'].map((b) => Map<String, String>.from(b)),
        );
      });
    }
  }

  void _loadRecentTransactions() {
    final transactions = context
        .read<TransactionProvider>()
        .transactions
        .where((t) => t.type == TransactionType.cable)
        .take(5)
        .toList();

    setState(() {
      _recentTransactions = transactions;
    });
  }

  Future<void> _saveBeneficiaryToStorage() async {
    if (!_saveBeneficiary || _smartcardController.text.trim().isEmpty) return;

    final smartcard = _smartcardController.text.trim();
    final provider = _selectedProvider ?? '';
    final customerName = _customerName ?? '';

    final exists = _beneficiaries.any((b) => b['smartcard'] == smartcard);
    if (exists) return;

    _beneficiaries.insert(0, {
      'smartcard': smartcard,
      'provider': provider,
      'customer_name': customerName,
    });

    if (_beneficiaries.length > 10) {
      _beneficiaries = _beneficiaries.sublist(0, 10);
    }

    final storage = StorageService();
    final beneficiaries = storage.getBeneficiaries();
    beneficiaries['cable'] = _beneficiaries;
    await storage.saveBeneficiaries(beneficiaries);
  }

  void _onProviderSelected(String provider) {
    setState(() {
      _selectedProvider = provider;
      _customerName = null;
      _selectedPlan = null;
      _isValidated = false;
      _allPlans = [];
      _searchedPlans = [];
      _searchController.clear();
    });
  }

  Future<void> _validateSmartcard() async {
    UiHelpers.dismissKeyboard(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvider == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select a provider',
        isError: true,
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _customerName = null;
      _isValidated = false;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.validateSmartcard(
      provider: _selectedProvider!,
      smartcard: _smartcardController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isValidating = false;
    });

    if (result.success && result.data != null) {
      setState(() {
        _customerName = result.data!['customer_name'];
        _isValidated = true;
      });

      UiHelpers.showSnackBar(context, 'Smartcard validated successfully');

      // Load packages
      _loadCablePlans(_selectedProvider!);
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Invalid smartcard number',
        isError: true,
      );
    }
  }

  Future<void> _loadCablePlans(String provider) async {
    setState(() {
      _isLoadingPlans = true;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getCablePlans();

    if (!mounted) return;

    setState(() {
      _isLoadingPlans = false;
    });

    if (result.success && result.data != null) {
      setState(() {
        // Parse plans from the nested map for the selected provider
        final providerPlans = result.data![provider] as List?;
        _allPlans = [];

        if (providerPlans != null) {
          for (final plan in providerPlans) {
            _allPlans.add(
              CablePlan.fromJson(Map<String, dynamic>.from(plan), provider),
            );
          }
        }

        _searchedPlans = _allPlans;
      });
    } else {
      setState(() {
        _loadPlansError = result.error ?? 'Failed to load packages';
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _searchedPlans = _allPlans;
      } else {
        _searchedPlans = _allPlans.where((plan) {
          return plan.name.toLowerCase().contains(query) ||
              plan.price.toString().contains(query) ||
              plan.duration.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectBeneficiary(Map<String, String> beneficiary) {
    setState(() {
      _smartcardController.text = beneficiary['smartcard'] ?? '';
      _selectedProvider = beneficiary['provider'];
      _customerName = null;
      _isValidated = false;
      _selectedPlan = null;
    });

    // Auto-validate
    if (_selectedProvider != null && _smartcardController.text.isNotEmpty) {
      _validateSmartcard();
    }
  }

  void _selectFromTransaction(Transaction transaction) {
    setState(() {
      _smartcardController.text = transaction.beneficiary ?? '';
      _selectedProvider = transaction.network;
      _customerName = null;
      _isValidated = false;
      _selectedPlan = null;
    });

    // Auto-validate
    if (_selectedProvider != null && _smartcardController.text.isNotEmpty) {
      _validateSmartcard();
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvider == null) {
      UiHelpers.showSnackBar(
        context,
        'Please select a provider',
        isError: true,
      );
      return;
    }

    if (!_isValidated) {
      UiHelpers.showSnackBar(
        context,
        'Please validate smartcard number',
        isError: true,
      );
      return;
    }

    if (_selectedPlan == null) {
      UiHelpers.showSnackBar(context, 'Please select a package', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow('Provider', _selectedProvider!),
            _buildConfirmRow('Smartcard', _smartcardController.text.trim()),
            _buildConfirmRow('Customer', _customerName ?? ''),
            _buildConfirmRow('Package', _selectedPlan!.name),
            _buildConfirmRow('Duration', _selectedPlan!.duration),
            const Divider(height: 24),
            _buildConfirmRow(
              'Amount',
              '₦${NumberFormat('#,##0.00').format(_selectedPlan!.price)}',
              isBold: true,
            ),
          ],
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
      _buyCable();
    }
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyCable() async {
    // Check internet connection
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      ErrorHandler.handleOfflineMode(context);
      return;
    }

    final smartcard = _smartcardController.text.trim();
    final amount = _selectedPlan!.price;

    // Check balance
    final balance = context.read<WalletProvider>().balance;
    if (balance < amount) {
      ErrorHandler.handleInsufficientBalance(context, balance, amount);
      return;
    }

    // Verify PIN
    final pinVerified = await showPinVerificationDialog(
      context,
      title: 'Enter PIN',
      subtitle: 'Authorize purchase of ${_selectedPlan!.name}',
    );

    if (!pinVerified) {
      UiHelpers.showSnackBar(context, 'Transaction cancelled', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Call API
    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.buyCable(
      provider: _selectedProvider!,
      planId: _selectedPlan!.id,
      smartcard: smartcard,
      pincode: '12345',
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (result.success && result.data != null) {
      // Save beneficiary if checked
      await _saveBeneficiaryToStorage();

      // Update balance
      final walletProvider = context.read<WalletProvider>();
      walletProvider.deductBalance(amount);

      // Create transaction
      final transaction = Transaction(
        id: result.data!['transaction_id'],
        type: TransactionType.cable,
        network: _selectedProvider!,
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: smartcard,
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + amount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'customer_name': _customerName ?? '',
          'package': _selectedPlan!.name,
          'duration': _selectedPlan!.duration,
        },
      );

      // Add to history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CableSuccessScreen(
            transaction: transaction,
            cablePlan: _selectedPlan!,
          ),
        ),
      );
    } else {
      ErrorHandler.handleApiError(context, result.error ?? 'Purchase failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkProvider = context.watch<NetworkProvider>();

    return GestureDetector(
      onTap: () => UiHelpers.dismissKeyboard(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Buy Cable TV'), centerTitle: true),
        body: LoadingOverlay(
          isLoading: _isProcessing,
          message: 'Processing cable TV purchase...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Network offline warning
                  OfflineBanner(isOffline: !networkProvider.isOnline),

                  // Provider Selector
                  Text(
                    'Select Provider',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _providers.map((provider) {
                      return Expanded(child: _buildProviderCard(provider));
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Smartcard Number
                  CustomTextField(
                    controller: _smartcardController,
                    labelText: 'Smartcard/IUC Number',
                    hintText: 'Enter smartcard number',
                    prefixIcon: Icons.credit_card,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter smartcard number';
                      }
                      if (value.trim().length < 10) {
                        return 'Smartcard number must be at least 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Validate Button
                  CustomButton(
                    text: _isValidated ? 'Validated ✓' : 'Validate Smartcard',
                    icon: _isValidated
                        ? Icons.check_circle
                        : Icons.verified_user,
                    onPressed: _isValidated ? null : _validateSmartcard,
                    isLoading: _isValidating,
                    backgroundColor: _isValidated ? Colors.green : null,
                  ),
                  const SizedBox(height: 16),

                  // Customer Name (after validation)
                  if (_customerName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Name',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _customerName!,
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Search Bar
                  if (_allPlans.isNotEmpty) ...[
                    CustomTextField(
                      controller: _searchController,
                      labelText: 'Search Packages',
                      hintText: 'Search by name, price, or duration',
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

                  // Cable Plans List
                  if (!_isLoadingPlans && _searchedPlans.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Package',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_searchedPlans.length} package${_searchedPlans.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
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
                        if (_selectedProvider != null)
                          _loadCablePlans(_selectedProvider!);
                      },
                    ),

                  // No plans message
                  if (!_isLoadingPlans &&
                      _loadPlansError == null &&
                      _isValidated &&
                      _searchedPlans.isEmpty &&
                      _allPlans.isNotEmpty)
                    EmptyState(
                      icon: Icons.inbox,
                      title: 'No packages found',
                      message: 'Try a different search term',
                      actionText: 'Clear search',
                      onAction: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
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
                    CustomButton(
                      text:
                          'Continue - ₦${NumberFormat('#,##0').format(_selectedPlan!.price)}',
                      onPressed: networkProvider.isOnline
                          ? _showConfirmationDialog
                          : null,
                      isLoading: _isProcessing,
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
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _beneficiaries.length,
                        itemBuilder: (context, index) {
                          final beneficiary = _beneficiaries[index];
                          return _buildBeneficiaryCard(beneficiary);
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
                    ..._recentTransactions.map((transaction) {
                      return _buildRecentTransactionCard(transaction);
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(String provider) {
    final isSelected = _selectedProvider == provider;

    Color getColor() {
      switch (provider) {
        case 'DSTV':
          return const Color(0xFF0033A0);
        case 'GOTV':
          return const Color(0xFFE30613);
        case 'STARTIMES':
          return const Color(0xFF00A651);
        default:
          return Colors.grey;
      }
    }

    final color = getColor();

    return GestureDetector(
      onTap: () => _onProviderSelected(provider),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.tv, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              provider,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(CablePlan plan) {
    final isSelected = _selectedPlan?.name == plan.name;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
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
            Radio<CablePlan>(
              value: plan,
              groupValue: _selectedPlan,
              onChanged: (value) {
                setState(() {
                  _selectedPlan = value;
                });
              },
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
                    plan.duration,
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
    final smartcard = beneficiary['smartcard'] ?? '';
    final provider = beneficiary['provider'] ?? '';
    final customerName = beneficiary['customer_name'] ?? '';

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
            Icon(Icons.tv, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(height: 6),
            Text(
              customerName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              smartcard,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              provider,
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
          backgroundColor: Colors.purple.withOpacity(0.1),
          child: const Icon(Icons.tv, color: Colors.purple),
        ),
        title: Text(transaction.metadata?['customer_name'] ?? ''),
        subtitle: Text(
          '${transaction.network} • ${transaction.metadata?['package'] ?? ''} • ₦${NumberFormat('#,##0').format(transaction.amount)}',
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
