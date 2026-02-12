import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../widgets/custom_button.dart';
import '../../utils/ui_helpers.dart';

class DatacardSuccessScreen extends StatefulWidget {
  final Transaction transaction;

  const DatacardSuccessScreen({super.key, required this.transaction});

  @override
  State<DatacardSuccessScreen> createState() => _DatacardSuccessScreenState();
}

class _DatacardSuccessScreenState extends State<DatacardSuccessScreen> {
  final Set<int> _revealedPins = {};
  bool _showAllPins = false;

  List<Map<String, dynamic>> get _pins {
    final pinsData = widget.transaction.metadata?['pins'];
    if (pinsData is List) {
      return List<Map<String, dynamic>>.from(pinsData);
    }
    return [];
  }

  String get _denomination =>
      widget.transaction.metadata?['denomination'] ?? '';
  String get _nameOnCard => widget.transaction.metadata?['name_on_card'] ?? '';

  void _togglePin(int index) {
    setState(() {
      if (_revealedPins.contains(index)) {
        _revealedPins.remove(index);
      } else {
        _revealedPins.add(index);
      }
    });
  }

  void _toggleAllPins() {
    setState(() {
      _showAllPins = !_showAllPins;
      if (_showAllPins) {
        _revealedPins.addAll(List.generate(_pins.length, (i) => i));
      } else {
        _revealedPins.clear();
      }
    });
  }

  void _copyPin(String serial, String pin) {
    Clipboard.setData(ClipboardData(text: 'Serial: $serial\nPIN: $pin'));
    UiHelpers.showSnackBar(context, 'PIN copied to clipboard');
  }

  void _copyAllPins() {
    final allPins = _pins
        .map((pin) {
          return 'Serial: ${pin['serial']}\nPIN: ${pin['pin']}';
        })
        .join('\n\n');

    Clipboard.setData(ClipboardData(text: allPins));
    UiHelpers.showSnackBar(context, 'All PINs copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Successful'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showAllPins ? Icons.visibility_off : Icons.visibility),
            onPressed: _toggleAllPins,
            tooltip: _showAllPins ? 'Hide all PINs' : 'Show all PINs',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Success Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 80,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Data Cards Generated!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.transaction.network} $_denomination • ${_pins.length} card${_pins.length > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_nameOnCard.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Name: $_nameOnCard',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Important Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.teal[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Save these PINs! They are hidden for security. Use them to load data on any compatible device.',
                                style: TextStyle(
                                  color: Colors.teal[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Pins List
                      ..._pins.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pin = entry.value;
                        return _buildPinCard(index, pin);
                      }),
                      const SizedBox(height: 24),

                      // Transaction Details
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Network',
                              widget.transaction.network,
                            ),
                            const Divider(height: 24),
                            _buildDetailRow('Denomination', _denomination),
                            if (_nameOnCard.isNotEmpty) ...[
                              const Divider(height: 24),
                              _buildDetailRow('Name on Card', _nameOnCard),
                            ],
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Quantity',
                              '${_pins.length} card${_pins.length > 1 ? 's' : ''}',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Amount',
                              '₦${NumberFormat('#,##0').format(widget.transaction.amount)}',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Reference',
                              widget.transaction.reference ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Date',
                              DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(widget.transaction.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Buttons
              Column(
                children: [
                  CustomButton(
                    text: 'Copy All PINs',
                    icon: Icons.copy_all,
                    onPressed: _copyAllPins,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Done',
                    isOutlined: true,
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinCard(int index, Map<String, dynamic> pinData) {
    final serial = pinData['serial'] ?? '';
    final pin = pinData['pin'] ?? '';
    final isRevealed = _revealedPins.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CARD ${index + 1}',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _togglePin(index),
                icon: Icon(
                  isRevealed ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                tooltip: isRevealed ? 'Hide PIN' : 'Show PIN',
              ),
              IconButton(
                onPressed: () => _copyPin(serial, pin),
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy PIN',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPinRow('Serial', serial, isRevealed),
          const SizedBox(height: 8),
          _buildPinRow('PIN', pin, isRevealed),
        ],
      ),
    );
  }

  Widget _buildPinRow(String label, String value, bool isRevealed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            isRevealed ? value : '•' * value.length,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isRevealed ? 16 : 20,
              fontFamily: isRevealed ? 'monospace' : null,
              letterSpacing: isRevealed ? 1 : 3,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
