import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/data_plan_model.dart';
import '../widgets/custom_button.dart';

class DataSuccessScreen extends StatelessWidget {
  final Transaction transaction;
  final DataPlan dataPlan;

  const DataSuccessScreen({
    super.key,
    required this.transaction,
    required this.dataPlan,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = '₦${NumberFormat('#,##0').format(transaction.amount)}';
    final dateText = DateFormat(
      'MMM dd, yyyy • hh:mm a',
    ).format(transaction.createdAt);

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
              // Scrollable content (prevents RenderFlex overflow on small screens)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                      const SizedBox(height: 24),

                      // Data Bundle
                      Text(
                        dataPlan.name,
                        style: TextStyle(
                          fontSize: 28, // responsive-friendly
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${transaction.network} Data',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Details Card
                      Container(
                        width: double.infinity,
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
                              'Data Type',
                              (transaction.metadata?['data_type'] ?? '')
                                  .toString(),
                            ),
                            const Divider(height: 24),
                            _buildDetailRow('Validity', dataPlan.validity),
                            const Divider(height: 24),
                            _buildDetailRow('Amount', amountText),
                            const Divider(height: 24),
                            _buildDetailRow(
                              'Reference',
                              transaction.reference ?? '',
                            ),
                            const Divider(height: 24),
                            _buildDetailRow('Date', dateText),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom buttons (always visible)
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Done',
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Buy Again',
                  isOutlined: true,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
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
