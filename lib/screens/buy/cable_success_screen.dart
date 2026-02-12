import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/cable_plan_model.dart';
import '../widgets/custom_button.dart';

class CableSuccessScreen extends StatelessWidget {
  final Transaction transaction;
  final CablePlan cablePlan;

  const CableSuccessScreen({
    super.key,
    required this.transaction,
    required this.cablePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Successful'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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

                    // Package Name
                    Text(
                      cablePlan.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${transaction.network} Subscription',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Provider', transaction.network),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Customer',
                            transaction.metadata?['customer_name'] ?? '',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Smartcard',
                            transaction.beneficiary ?? '',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Package', cablePlan.name),
                          const Divider(height: 20),
                          _buildDetailRow('Duration', cablePlan.duration),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Amount',
                            '₦${NumberFormat('#,##0').format(transaction.amount)}',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Reference',
                            transaction.reference ?? '',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Date',
                            DateFormat(
                              'MMM dd, yyyy • hh:mm a',
                            ).format(transaction.createdAt),
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
                    text: 'Done',
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Buy Again',
                    isOutlined: true,
                    onPressed: () {
                      Navigator.pop(context);
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
