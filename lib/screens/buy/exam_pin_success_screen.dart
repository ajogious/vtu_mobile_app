import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../widgets/custom_button.dart';
import '../../utils/ui_helpers.dart';

class ExamPinSuccessScreen extends StatefulWidget {
  final Transaction transaction;

  const ExamPinSuccessScreen({super.key, required this.transaction});

  @override
  State<ExamPinSuccessScreen> createState() => _ExamPinSuccessScreenState();
}

class _ExamPinSuccessScreenState extends State<ExamPinSuccessScreen> {
  final Set<int> _revealedPins = {};
  bool _showAllPins = false;

  List<Map<String, dynamic>> get _pins {
    final pinsData = widget.transaction.metadata?['pins'];
    if (pinsData is List) {
      return List<Map<String, dynamic>>.from(pinsData);
    }
    return [];
  }

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
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    // Success Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Exam Pins Generated!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.transaction.network} • ${_pins.length} pin${_pins.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Important Notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange[700],
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Save these PINs! They are hidden for security. You can view them anytime in your transaction history.',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pins List
                    ..._pins.asMap().entries.map((entry) {
                      final index = entry.key;
                      final pin = entry.value;
                      return _buildPinCard(index, pin);
                    }),
                    const SizedBox(height: 20),

                    // Transaction Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Exam Type',
                            widget.transaction.network,
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Quantity',
                            '${_pins.length} pin${_pins.length > 1 ? 's' : ''}',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Amount',
                            '₦${NumberFormat('#,##0').format(widget.transaction.amount)}',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Reference',
                            widget.transaction.reference ?? '',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Date',
                            DateFormat(
                              'MMM dd, yyyy • hh:mm a',
                            ).format(widget.transaction.createdAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Fixed Buttons at Bottom
            Container(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            ),
          ],
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
      padding: const EdgeInsets.all(14),
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
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PIN ${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
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
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: isRevealed ? 'Hide PIN' : 'Show PIN',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _copyPin(serial, pin),
                icon: const Icon(Icons.copy, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Copy PIN',
              ),
            ],
          ),
          const SizedBox(height: 10),
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
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13.5)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            isRevealed ? value : '•' * value.length,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isRevealed ? 15 : 18,
              fontFamily: isRevealed ? 'monospace' : null,
              letterSpacing: isRevealed ? 1 : 3,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13.5)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
