import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  Color _getTypeColor() {
    switch (transaction.type) {
      case TransactionType.airtime:
        return Colors.blue;
      case TransactionType.data:
        return Colors.green;
      case TransactionType.cable:
        return Colors.purple;
      case TransactionType.electricity:
        return Colors.orange;
      case TransactionType.examPin:
        return Colors.red;
      case TransactionType.dataCard:
        return Colors.teal;
      case TransactionType.walletFunding:
        return Colors.indigo;
      case TransactionType.atc:
        return Colors.pink;
      case TransactionType.referralBonus:
        return Colors.amber;
      case TransactionType.referralWithdrawal:
        return Colors.blueGrey;
    }
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
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
        return Icons.money_off;
    }
  }

  String _getTypeLabel() {
    switch (transaction.type) {
      case TransactionType.airtime:
        return 'Airtime';
      case TransactionType.data:
        return 'Data';
      case TransactionType.cable:
        return 'Cable TV';
      case TransactionType.electricity:
        return 'Electricity';
      case TransactionType.examPin:
        return 'Exam Pin';
      case TransactionType.dataCard:
        return 'Data Card';
      case TransactionType.walletFunding:
        return 'Wallet Funding';
      case TransactionType.atc:
        return 'Airtime to Cash';
      case TransactionType.referralBonus:
        return 'Referral Bonus';
      case TransactionType.referralWithdrawal:
        return 'Referral Withdrawal';
    }
  }

  Color _getStatusColor() {
    switch (transaction.status) {
      case TransactionStatus.success:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }

  String _getStatusLabel() {
    return transaction.status.name[0].toUpperCase() +
        transaction.status.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getTypeIcon(), color: color, size: 24),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getTypeLabel(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(transaction.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                transaction.type ==
                                        TransactionType.walletFunding ||
                                    transaction.type ==
                                        TransactionType.referralBonus
                                ? Colors.green
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.network}${transaction.beneficiary != null ? ' • ${transaction.beneficiary}' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusLabel(),
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Date
                        Expanded(
                          child: Text(
                            DateFormat(
                              'MMM dd, yyyy • hh:mm a',
                            ).format(transaction.createdAt),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
