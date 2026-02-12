import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../widgets/custom_button.dart';
import '../../utils/ui_helpers.dart';

class ElectricitySuccessScreen extends StatelessWidget {
  final Transaction transaction;

  const ElectricitySuccessScreen({super.key, required this.transaction});

  void _copyToken(BuildContext context, String token) {
    Clipboard.setData(ClipboardData(text: token));
    UiHelpers.showSnackBar(context, 'Token copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final token = transaction.metadata?['token'] ?? '';
    final units = transaction.metadata?['units'] ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Successful'),
        centerTitle: true,
        automaticallyImplyLeading: false,
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
                        'Payment Successful!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Electricity Token Generated',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),

                      // Token Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange[200]!,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'YOUR TOKEN',
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _copyToken(context, token),
                                  icon: Icon(
                                    Icons.copy,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  tooltip: 'Copy token',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              token,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$units Units',
                                    style: TextStyle(
                                      color: Colors.orange[900],
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

                      // Important Note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please save or write down this token. You will need it to recharge your meter.',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('DISCO', transaction.network),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Customer',
                              transaction.metadata?['customer_name'] ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Meter Number',
                              transaction.beneficiary ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Meter Type',
                              transaction.metadata?['meter_type'] ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Amount',
                              '₦${NumberFormat('#,##0').format(transaction.amount)}',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Reference',
                              transaction.reference ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Date',
                              DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(transaction.createdAt),
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
                    text: 'Copy Token',
                    icon: Icons.copy,
                    onPressed: () => _copyToken(context, token),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
