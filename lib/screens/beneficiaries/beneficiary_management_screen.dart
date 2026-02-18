// ignore_for_file: unused_import, unused_field

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/empty_state.dart';
import '../widgets/pin_verification_dialog.dart';
import '../../utils/ui_helpers.dart';

class BeneficiaryManagementScreen extends StatefulWidget {
  final String serviceType; // 'airtime', 'data', 'cable', 'electricity'

  const BeneficiaryManagementScreen({super.key, required this.serviceType});

  @override
  State<BeneficiaryManagementScreen> createState() =>
      _BeneficiaryManagementScreenState();
}

class _BeneficiaryManagementScreenState
    extends State<BeneficiaryManagementScreen> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _beneficiaries = [];
  List<Map<String, String>> _filteredBeneficiaries = [];
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBeneficiaries();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBeneficiaries() {
    final storage = StorageService();
    final all = storage.getBeneficiaries();
    final serviceList = all[widget.serviceType];

    if (serviceList != null) {
      setState(() {
        _beneficiaries = List<Map<String, String>>.from(
          serviceList.map((b) => Map<String, String>.from(b)),
        );
        _filteredBeneficiaries = List.from(_beneficiaries);
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBeneficiaries = List.from(_beneficiaries);
      } else {
        _filteredBeneficiaries = _beneficiaries.where((b) {
          return b.values.any((v) => v.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  Future<void> _deleteBeneficiary(
    Map<String, String> beneficiary,
    int index,
  ) async {
    // Re-authenticate before deleting
    final authenticated = await requireReAuthentication(
      context,
      action: 'delete this beneficiary',
    );

    if (!authenticated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: Text(
          'Are you sure you want to delete ${_getBeneficiaryName(beneficiary)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _beneficiaries.removeWhere((b) => b == beneficiary);
      _filteredBeneficiaries.removeWhere((b) => b == beneficiary);
    });

    // Save to storage
    final storage = StorageService();
    final all = storage.getBeneficiaries();
    all[widget.serviceType] = _beneficiaries;
    await storage.saveBeneficiaries(all);

    if (!mounted) return;
    UiHelpers.showSnackBar(context, 'Beneficiary deleted');
  }

  Future<void> _editBeneficiary(
    Map<String, String> beneficiary,
    int index,
  ) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditBeneficiarySheet(
        beneficiary: beneficiary,
        serviceType: widget.serviceType,
      ),
    );

    if (result == null) return;

    setState(() {
      final originalIndex = _beneficiaries.indexWhere((b) => b == beneficiary);
      if (originalIndex != -1) {
        _beneficiaries[originalIndex] = result;
      }
      _onSearchChanged();
    });

    // Save to storage
    final storage = StorageService();
    final all = storage.getBeneficiaries();
    all[widget.serviceType] = _beneficiaries;
    await storage.saveBeneficiaries(all);

    if (!mounted) return;
    UiHelpers.showSnackBar(context, 'Beneficiary updated');
  }

  String _getBeneficiaryName(Map<String, String> b) {
    return b['customer_name'] ??
        b['phone'] ??
        b['meter'] ??
        b['smartcard'] ??
        'Beneficiary';
  }

  String _getBeneficiarySubtitle(Map<String, String> b) {
    final parts = <String>[];
    if (b['phone'] != null) parts.add(b['phone']!);
    if (b['meter'] != null) parts.add(b['meter']!);
    if (b['smartcard'] != null) parts.add(b['smartcard']!);
    if (b['network'] != null) parts.add(b['network']!);
    if (b['disco'] != null) parts.add(b['disco']!);
    if (b['provider'] != null) parts.add(b['provider']!);
    if (b['meter_type'] != null) parts.add(b['meter_type']!);
    return parts.join(' • ');
  }

  IconData _getServiceIcon() {
    switch (widget.serviceType) {
      case 'airtime':
        return Icons.phone_android;
      case 'data':
        return Icons.wifi;
      case 'cable':
        return Icons.tv;
      case 'electricity':
        return Icons.bolt;
      default:
        return Icons.person;
    }
  }

  Color _getServiceColor() {
    switch (widget.serviceType) {
      case 'airtime':
        return Colors.blue;
      case 'data':
        return Colors.green;
      case 'cable':
        return Colors.purple;
      case 'electricity':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.serviceType[0].toUpperCase()}${widget.serviceType.substring(1)} Beneficiaries',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomTextField(
              controller: _searchController,
              labelText: 'Search Beneficiaries',
              hintText: 'Search by name, number...',
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
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredBeneficiaries.length} beneficiar${_filteredBeneficiaries.length != 1 ? 'ies' : 'y'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: _filteredBeneficiaries.isEmpty
                ? EmptyState(
                    icon: _getServiceIcon(),
                    title: _searchController.text.isNotEmpty
                        ? 'No results found'
                        : 'No Beneficiaries',
                    message: _searchController.text.isNotEmpty
                        ? 'Try a different search term'
                        : 'Saved beneficiaries will appear here',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredBeneficiaries.length,
                    itemBuilder: (context, index) {
                      final b = _filteredBeneficiaries[index];
                      return _buildBeneficiaryCard(b, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryCard(Map<String, String> b, int index) {
    final color = _getServiceColor();
    final name = _getBeneficiaryName(b);
    final subtitle = _getBeneficiarySubtitle(b);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editBeneficiary(b, index),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteBeneficiary(b, index),
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: () {
          // Return selected beneficiary
          Navigator.pop(context, b);
        },
      ),
    );
  }
}

// ─── Edit Beneficiary Bottom Sheet ────────────────────────────────────────────

class _EditBeneficiarySheet extends StatefulWidget {
  final Map<String, String> beneficiary;
  final String serviceType;

  const _EditBeneficiarySheet({
    required this.beneficiary,
    required this.serviceType,
  });

  @override
  State<_EditBeneficiarySheet> createState() => _EditBeneficiarySheetState();
}

class _EditBeneficiarySheetState extends State<_EditBeneficiarySheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    widget.beneficiary.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Beneficiary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ..._controllers.entries.where((e) => e.key != 'data_type').map((
              entry,
            ) {
              final label = entry.key
                  .split('_')
                  .map((w) => w[0].toUpperCase() + w.substring(1))
                  .join(' ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CustomTextField(
                  controller: entry.value,
                  labelText: label,
                  prefixIcon: Icons.edit,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              );
            }),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                final updated = <String, String>{};
                _controllers.forEach((key, ctrl) {
                  updated[key] = ctrl.text.trim();
                });
                Navigator.pop(context, updated);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
