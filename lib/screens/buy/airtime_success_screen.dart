import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../widgets/custom_button.dart';

class AirtimeSuccessScreen extends StatelessWidget {
  final Transaction transaction;

  const AirtimeSuccessScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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

                    // Amount
                    Text(
                      '₦${NumberFormat('#,##0.00').format(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${transaction.network} Airtime',
                      style: Theme.of(context).textTheme.titleLarge,
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
                          _buildDetailRow(
                            'Phone Number',
                            transaction.beneficiary ?? '',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow('Network', transaction.network),
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

              // Buttons
              Column(
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
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
