import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../utils/ui_helpers.dart';
import '../widgets/custom_button.dart';
import '../widgets/receipt_generator.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final Set<int> _revealedPins = {};
  bool _showAllPins = false;

  Color _getStatusColor() {
    switch (widget.transaction.status) {
      case TransactionStatus.success:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }

  String _getStatusLabel() {
    return widget.transaction.status.name[0].toUpperCase() +
        widget.transaction.status.name.substring(1);
  }

  IconData _getTypeIcon() {
    switch (widget.transaction.type) {
      case TransactionType.airtime:
        return Icons.phone_android;
      case TransactionType.data:
        return Icons.wifi;
      case TransactionType.cable:
        return Icons.tv;
      case TransactionType.electricity:
        return Icons.bolt;
      case TransactionType.examPin:
        return Icons.school;
      case TransactionType.dataCard:
        return Icons.card_giftcard;
      case TransactionType.walletFunding:
        return Icons.account_balance_wallet;
      case TransactionType.atc:
        return Icons.phone_callback;
      case TransactionType.referralBonus:
        return Icons.card_giftcard;
      case TransactionType.referralWithdrawal:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  String _getTypeLabel() {
    switch (widget.transaction.type) {
      case TransactionType.airtime:
        return 'Airtime Purchase';
      case TransactionType.data:
        return 'Data Purchase';
      case TransactionType.cable:
        return 'Cable TV Subscription';
      case TransactionType.electricity:
        return 'Electricity Payment';
      case TransactionType.examPin:
        return 'Exam Pin Purchase';
      case TransactionType.dataCard:
        return 'Data Card Purchase';
      case TransactionType.walletFunding:
        return 'Wallet Funding';
      case TransactionType.atc:
        return 'Airtime to Cash';
      case TransactionType.referralBonus:
        return 'Referral Bonus';
      case TransactionType.referralWithdrawal:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    UiHelpers.showSnackBar(context, '$label copied to clipboard');
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
    final pins = _getPins();
    setState(() {
      _showAllPins = !_showAllPins;
      if (_showAllPins) {
        _revealedPins.addAll(List.generate(pins.length, (i) => i));
      } else {
        _revealedPins.clear();
      }
    });
  }

  List<Map<String, dynamic>> _getPins() {
    final pinsData = widget.transaction.metadata?['pins'];
    if (pinsData is List) {
      return List<Map<String, dynamic>>.from(pinsData);
    }
    return [];
  }

  Future<void> _generateReceipt() async {
    try {
      await ReceiptGenerator.generateAndShare(context, widget.transaction);
    } catch (e) {
      UiHelpers.showSnackBar(
        context,
        'Failed to generate receipt: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        centerTitle: true,
        actions: [
          if (widget.transaction.type == TransactionType.examPin ||
              widget.transaction.type == TransactionType.dataCard)
            IconButton(
              icon: Icon(
                _showAllPins ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: _toggleAllPins,
              tooltip: _showAllPins ? 'Hide all PINs' : 'Show all PINs',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [statusColor, statusColor.withOpacity(0.8)],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.transaction.status == TransactionStatus.success
                        ? Icons.check_circle
                        : widget.transaction.status == TransactionStatus.pending
                        ? Icons.access_time
                        : Icons.error,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getStatusLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦${NumberFormat('#,##0.00').format(widget.transaction.amount)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Transaction Type Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getTypeIcon(),
                              color: statusColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTypeLabel(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.transaction.network,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reference Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Reference Number',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () => _copyToClipboard(
                                  widget.transaction.reference ?? '',
                                  'Reference',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.transaction.reference ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Transaction Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Date & Time',
                            DateFormat(
                              'MMM dd, yyyy • hh:mm:ss a',
                            ).format(widget.transaction.createdAt),
                          ),
                          if (widget.transaction.beneficiary != null) ...[
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Beneficiary',
                              widget.transaction.beneficiary!,
                            ),
                          ],
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Transaction ID',
                            widget.transaction.id,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Balance Before',
                            '₦${NumberFormat('#,##0.00').format(widget.transaction.balanceBefore)}',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Balance After',
                            '₦${NumberFormat('#,##0.00').format(widget.transaction.balanceAfter)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Electricity Token
                  if (widget.transaction.type == TransactionType.electricity &&
                      widget.transaction.metadata?['token'] != null) ...[
                    _buildTokenCard(),
                    const SizedBox(height: 16),
                  ],

                  // Exam Pins
                  if (widget.transaction.type == TransactionType.examPin &&
                      _getPins().isNotEmpty) ...[
                    _buildPinsCard('Exam Pins'),
                    const SizedBox(height: 16),
                  ],

                  // Data Cards
                  if (widget.transaction.type == TransactionType.dataCard &&
                      _getPins().isNotEmpty) ...[
                    _buildPinsCard('Data Cards'),
                    const SizedBox(height: 16),
                  ],

                  // Additional Metadata
                  if (widget.transaction.metadata != null &&
                      widget.transaction.metadata!.isNotEmpty) ...[
                    _buildMetadataCard(),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  CustomButton(
                    text: 'Download Receipt',
                    icon: Icons.receipt_long,
                    onPressed: _generateReceipt,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Close',
                    isOutlined: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenCard() {
    final token = widget.transaction.metadata?['token'] ?? '';
    final units = widget.transaction.metadata?['units'] ?? '0';

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ELECTRICITY TOKEN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyToClipboard(token, 'Token'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              token,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$units Units',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinsCard(String title) {
    final pins = _getPins();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...pins.asMap().entries.map((entry) {
              final index = entry.key;
              final pin = entry.value;
              return _buildPinItem(index, pin);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPinItem(int index, Map<String, dynamic> pinData) {
    final serial = pinData['serial'] ?? '';
    final pin = pinData['pin'] ?? '';
    final isRevealed = _revealedPins.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isRevealed ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => _togglePin(index),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () =>
                    _copyToClipboard('Serial: $serial\nPIN: $pin', 'PIN'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPinRow('Serial', serial, isRevealed),
          const SizedBox(height: 4),
          _buildPinRow('PIN', pin, isRevealed),
        ],
      ),
    );
  }

  Widget _buildPinRow(String label, String value, bool isRevealed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(
          isRevealed ? value : '•' * value.length,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isRevealed ? 14 : 18,
            fontFamily: isRevealed ? 'monospace' : null,
            letterSpacing: isRevealed ? 1 : 3,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard() {
    final metadata = widget.transaction.metadata!;
    final displayData = Map<String, dynamic>.from(metadata);

    // Remove pins and token as they're displayed separately
    displayData.remove('pins');
    displayData.remove('token');
    displayData.remove('units');

    if (displayData.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...displayData.entries.map((entry) {
              final label = entry.key
                  .split('_')
                  .map((word) {
                    return word[0].toUpperCase() + word.substring(1);
                  })
                  .join(' ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDetailRow(label, entry.value.toString()),
              );
            }),
          ],
        ),
      ),
    );
  }
}
