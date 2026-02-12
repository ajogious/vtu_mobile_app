import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/transaction_provider.dart';
import '../widgets/network_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/pin_verification_dialog.dart';
import '../../utils/validators.dart';
import '../../utils/ui_helpers.dart';
import '../../services/storage_service.dart';
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
  bool _isLoadingPlans = false;
  bool _isProcessing = false;

  List<DataPlan> _allPlans = [];
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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
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
    final transactions = context
        .read<TransactionProvider>()
        .transactions
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
      // Step 1: Check and request permission
      PermissionStatus status = await Permission.contacts.status;

      if (status.isDenied) {
        status = await Permission.contacts.request();
      }

      // Handle permanently denied
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

      // If not granted, show error
      if (!status.isGranted) {
        if (!mounted) return;
        UiHelpers.showSnackBar(
          context,
          'Contact permission is required to pick a number',
          isError: true,
        );
        return;
      }

      // Step 2: Pick a contact (External Picker)
      final contact = await FlutterContacts.openExternalPick();

      if (contact == null) {
        return;
      }

      // Step 3: Fetch full contact details
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

      // Step 4: Get and clean phone number
      String phone = fullContact.phones.first.number;

      // Clean phone number (remove spaces, dashes, parentheses)
      phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

      // Remove country code if present
      if (phone.startsWith('+234')) {
        phone = '0${phone.substring(4)}';
      } else if (phone.startsWith('234')) {
        phone = '0${phone.substring(3)}';
      }

      // Ensure it starts with 0
      if (!phone.startsWith('0') && phone.length >= 10) {
        phone = '0$phone';
      }

      // Limit to 11 digits
      if (phone.length > 11) {
        phone = phone.substring(0, 11);
      }

      if (mounted) {
        setState(() {
          _phoneController.text = phone;
        });

        UiHelpers.showSnackBar(
          context,
          'Contact added successfully',
          isError: false,
        );
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
      _dataTypes = [];
      _filteredPlans = [];
      _searchedPlans = [];
      _searchController.clear();
    });

    _loadDataPlans(network);
  }

  Future<void> _loadDataPlans(String network) async {
    setState(() {
      _isLoadingPlans = true;
    });

    final authService = context.read<AuthProvider>().authService;
    final result = await authService.api.getDataPlans();

    if (!mounted) return;

    setState(() {
      _isLoadingPlans = false;
    });

    if (result.success && result.data != null) {
      setState(() {
        // Parse plans from the nested map for the selected network
        final networkData = result.data![network] as Map<String, dynamic>?;
        _allPlans = [];

        if (networkData != null) {
          networkData.forEach((type, plans) {
            final planList = plans as List;
            for (final plan in planList) {
              _allPlans.add(
                DataPlan.fromJson(
                  Map<String, dynamic>.from(plan),
                  network,
                  type,
                ),
              );
            }
          });
        }

        // Extract unique data types
        _dataTypes = _allPlans.map((plan) => plan.type).toSet().toList();

        // Auto-select first type if available
        if (_dataTypes.isNotEmpty) {
          _selectedDataType = _dataTypes.first;
          _filterPlansByType(_selectedDataType!);
        }
      });
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Failed to load data plans',
        isError: true,
      );
    }
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

      if (_selectedNetwork != null) {
        _loadDataPlans(_selectedNetwork!);

        if (beneficiary['data_type'] != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_dataTypes.contains(beneficiary['data_type'])) {
              _filterPlansByType(beneficiary['data_type']!);
            }
          });
        }
      }
    });
  }

  void _selectFromTransaction(Transaction transaction) {
    setState(() {
      _phoneController.text = transaction.beneficiary ?? '';
      _selectedNetwork = transaction.network;

      if (_selectedNetwork != null) {
        _loadDataPlans(_selectedNetwork!);

        final dataType = transaction.metadata?['data_type'];
        if (dataType != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_dataTypes.contains(dataType)) {
              _filterPlansByType(dataType);

              // Try to find and select the same plan
              final bundle = transaction.metadata?['bundle'];
              if (bundle != null) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  final plan = _searchedPlans.firstWhere(
                    (p) => p.name == bundle,
                    orElse: () => _searchedPlans.first,
                  );
                  setState(() {
                    _selectedPlan = plan;
                  });
                });
              }
            }
          });
        }
      }
    });
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
    // Check internet connection
    final isOnline = context.read<NetworkProvider>().isOnline;
    if (!isOnline) {
      UiHelpers.showSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final amount = _selectedPlan!.price;

    // Check balance
    final balance = context.read<WalletProvider>().balance;
    if (balance < amount) {
      UiHelpers.showSnackBar(
        context,
        'Insufficient balance. Please fund your wallet.',
        isError: true,
      );
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
    final result = await authService.api.buyData(
      network: _selectedNetwork!,
      type: _selectedDataType!,
      dataBundle: _selectedPlan!.name,
      number: phone,
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
        type: TransactionType.data,
        network: _selectedNetwork!,
        amount: amount,
        status: TransactionStatus.success,
        createdAt: DateTime.now(),
        beneficiary: phone,
        reference: result.data!['reference'],
        balanceBefore: result.data!['balance'] + amount,
        balanceAfter: result.data!['balance'],
        metadata: {
          'data_type': _selectedDataType!,
          'bundle': _selectedPlan!.name,
          'validity': _selectedPlan!.validity,
        },
      );

      // Add to history
      context.read<TransactionProvider>().addTransaction(transaction);

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DataSuccessScreen(
            transaction: transaction,
            dataPlan: _selectedPlan!,
          ),
        ),
      );
    } else {
      UiHelpers.showSnackBar(
        context,
        result.error ?? 'Purchase failed',
        isError: true,
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Network offline warning
                if (!networkProvider.isOnline)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No internet connection. Purchase disabled.',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Network Selector
                NetworkSelector(
                  selectedNetwork: _selectedNetwork,
                  onNetworkSelected: _onNetworkSelected,
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
                    Container(
                      margin: const EdgeInsets.only(top: 0),
                      child: IconButton(
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
                          if (selected) {
                            _filterPlansByType(type);
                          }
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
                    onChanged: (value) {
                      // Triggers _onSearchChanged via listener
                    },
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
                      Text(
                        '${_searchedPlans.length} plan${_searchedPlans.length != 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._searchedPlans.map((plan) => _buildPlanCard(plan)),
                  const SizedBox(height: 16),
                ],

                // No plans message
                if (!_isLoadingPlans &&
                    _selectedNetwork != null &&
                    _searchedPlans.isEmpty &&
                    _selectedDataType != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No plans found'
                              : 'No plans available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_searchController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
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
                    height: 85,
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
    );
  }

  Widget _buildPlanCard(DataPlan plan) {
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
            Radio<DataPlan>(
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
