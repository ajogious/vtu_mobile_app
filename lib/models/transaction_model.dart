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
      type: _parseTransactionType(json['service'] ?? json['type']),
      network: json['network'] ?? '',
      amount: double.parse(json['amount']?.toString() ?? '0'),
      status: _parseStatus(json['status']),
      createdAt: _parseDate(json['time'] ?? json['created_at']),
      beneficiary: json['beneficiary'] ?? json['buyer'],
      reference: json['transactionID'] ?? json['reference'],
      balanceBefore: json['prebalance'] != null
          ? double.parse(json['prebalance'].toString())
          : json['balance_before'] != null
          ? double.parse(json['balance_before'].toString())
          : null,
      balanceAfter: json['postbalance'] != null
          ? double.parse(json['postbalance'].toString())
          : json['balance_after'] != null
          ? double.parse(json['balance_after'].toString())
          : null,
      metadata: {
        if (json['descri'] != null) 'description': json['descri'],
        if (json['token'] != null && json['token'] != '')
          'token': json['token'],
        if (json['response'] != null && json['response'] != '')
          'response': json['response'],
        if (json['metadata'] != null) ...json['metadata'],
      },
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

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      // ISO format (local/mock transactions)
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        // API format: "10-02-2026 04:22 PM"
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final isPm = parts[2].toUpperCase() == 'PM';

        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        return DateTime(
          int.parse(dateParts[2]), // year
          int.parse(dateParts[1]), // month
          int.parse(dateParts[0]), // day
          hour,
          minute,
        );
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  static TransactionType _parseTransactionType(String? type) {
    switch (type?.toLowerCase()) {
      case 'airtime':
      case 'airtime purchase':
        return TransactionType.airtime;
      case 'data':
      case 'data purchase':
        return TransactionType.data;
      case 'cable':
      case 'cable subscription':
        return TransactionType.cable;
      case 'electricity':
      case 'electric':
      case 'electricity purchase':
        return TransactionType.electricity;
      case 'exam_pin':
      case 'exam':
      case 'exam pin':
      case 'exam pin purchase':
        return TransactionType.examPin;
      case 'datacard':
      case 'data_card':
      case 'data card':
      case 'data card purchase':
        return TransactionType.dataCard;
      case 'wallet_funding':
      case 'wallet':
      case 'funding':
      case 'wallet credit':
        return TransactionType.walletFunding;
      case 'atc':
      case 'airtime_to_cash':
      case 'airtime to cash':
        return TransactionType.atc;
      case 'referral':
      case 'referral_withdrawal':
      case 'referral withdrawal':
        return TransactionType.referralWithdrawal;
      case 'referral_bonus':
      case 'referral bonus':
        return TransactionType.referralBonus;
      default:
        return TransactionType.airtime;
    }
  }

  static TransactionStatus _parseStatus(String? status) {
    final normalized = status?.toLowerCase().trim();

    switch (normalized) {
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
      case 'reversed': // 🔥 ADD THIS
      case 'error':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.failed; // safer fallback
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
    // Handle both real API format and mock format
    final data = json['data'] ?? json;
    final transactionsList = data['transactions'] as List? ?? [];

    return PaginatedTransactions(
      transactions: transactionsList
          .map((t) => Transaction.fromJson(t))
          .toList(),
      currentPage: 1,
      totalPages: 1,
      perPage: data['limit'] ?? 50,
      totalRecords: transactionsList.length,
    );
  }

  bool get hasMore => currentPage < totalPages;
}
