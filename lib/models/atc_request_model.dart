enum ATCStatus { pending, approved, rejected }

class ATCRequest {
  final String id;
  final String network;
  final double amount;
  final double receivableAmount;
  final double conversionRate;
  final String phoneNumber;
  final ATCStatus status;
  final DateTime createdAt;
  final String? rejectionReason;

  ATCRequest({
    required this.id,
    required this.network,
    required this.amount,
    required this.receivableAmount,
    required this.conversionRate,
    required this.phoneNumber,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  factory ATCRequest.fromJson(Map<String, dynamic> json) {
    return ATCRequest(
      id: json['id'].toString(),
      network: json['network'] ?? '',
      amount: double.parse(json['amount']?.toString() ?? '0'),
      receivableAmount: double.parse(
        json['receivable_amount']?.toString() ?? '0',
      ),
      conversionRate: double.parse(json['conversion_rate']?.toString() ?? '0'),
      phoneNumber: json['phone_number'] ?? '',
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      rejectionReason: json['rejection_reason'],
    );
  }

  static ATCStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return ATCStatus.approved;
      case 'rejected':
        return ATCStatus.rejected;
      default:
        return ATCStatus.pending;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ATCStatus.pending:
        return 'Pending';
      case ATCStatus.approved:
        return 'Approved';
      case ATCStatus.rejected:
        return 'Rejected';
    }
  }
}
