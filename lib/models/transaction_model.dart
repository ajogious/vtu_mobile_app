enum TransactionType {
  airtime,
  data,
  cable,
  electricity,
  examPin,
  dataCard,
  walletFunding,
  atc,
  referralWithdrawal,
  referralBonus,
}

enum TransactionStatus { success, pending, failed }

class Transaction {
  final String id;
  final TransactionType type;
  final String network;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? beneficiary;
  final String? reference;
  final double? balanceBefore;
  final double? balanceAfter;
  final Map<String, dynamic>? metadata;

  Transaction({
    required this.id,
    required this.type,
    required this.network,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.beneficiary,
    this.reference,
    this.balanceBefore,
    this.balanceAfter,
    this.metadata,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      type: _parseTransactionType(json['type']),
      network: json['network'] ?? '',
      amount: double.parse(json['amount']?.toString() ?? '0'),
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      beneficiary: json['beneficiary'],
      reference: json['reference'],
      balanceBefore: json['balance_before'] != null
          ? double.parse(json['balance_before'].toString())
          : null,
      balanceAfter: json['balance_after'] != null
          ? double.parse(json['balance_after'].toString())
          : null,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'network': network,
      'amount': amount,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'beneficiary': beneficiary,
      'reference': reference,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'metadata': metadata,
    };
  }

  static TransactionType _parseTransactionType(String? type) {
    switch (type?.toLowerCase()) {
      case 'airtime':
        return TransactionType.airtime;
      case 'data':
        return TransactionType.data;
      case 'cable':
        return TransactionType.cable;
      case 'electricity':
      case 'electric':
        return TransactionType.electricity;
      case 'exam_pin':
      case 'exam':
        return TransactionType.examPin;
      case 'datacard':
      case 'data_card':
        return TransactionType.dataCard;
      case 'wallet_funding':
      case 'wallet':
      case 'funding':
        return TransactionType.walletFunding;
      case 'atc':
      case 'airtime_to_cash':
        return TransactionType.atc;
      case 'referral':
      case 'referral_withdrawal':
        return TransactionType.referralWithdrawal;
      case 'referral_bonus':
        return TransactionType.referralBonus;
      default:
        return TransactionType.airtime;
    }
  }

  static TransactionStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'success':
      case 'successful':
      case 'completed':
        return TransactionStatus.success;
      case 'pending':
      case 'processing':
        return TransactionStatus.pending;
      case 'failed':
      case 'declined':
      case 'rejected':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
  }

  String get typeDisplayName {
    switch (type) {
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
      case TransactionType.referralWithdrawal:
        return 'Referral Withdrawal';
      case TransactionType.referralBonus:
        return 'Referral Bonus';
    }
  }
}

class PaginatedTransactions {
  final List<Transaction> transactions;
  final int currentPage;
  final int totalPages;
  final int perPage;
  final int totalRecords;

  PaginatedTransactions({
    required this.transactions,
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
    required this.totalRecords,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    return PaginatedTransactions(
      transactions: (json['transactions'] as List)
          .map((t) => Transaction.fromJson(t))
          .toList(),
      currentPage: json['pagination']['current_page'] ?? 1,
      totalPages: json['pagination']['total_pages'] ?? 1,
      perPage: json['pagination']['per_page'] ?? 10,
      totalRecords: json['pagination']['total_records'] ?? 0,
    );
  }

  bool get hasMore => currentPage < totalPages;
}
