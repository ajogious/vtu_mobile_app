class ReferralStats {
  final double totalEarnings;
  final double availableBalance;
  final int totalReferrals;
  final int activeReferrals;

  ReferralStats({
    required this.totalEarnings,
    required this.availableBalance,
    required this.totalReferrals,
    required this.activeReferrals,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      totalEarnings: double.parse(json['total_earnings']?.toString() ?? '0'),
      availableBalance: double.parse(
        json['available_balance']?.toString() ?? '0',
      ),
      totalReferrals: json['total_referrals'] ?? 0,
      activeReferrals: json['active_referrals'] ?? 0,
    );
  }
}

class ReferralEarning {
  final String id;
  final double amount;
  final String source;
  final String transactionId;
  final DateTime createdAt;

  ReferralEarning({
    required this.id,
    required this.amount,
    required this.source,
    required this.transactionId,
    required this.createdAt,
  });

  factory ReferralEarning.fromJson(Map<String, dynamic> json) {
    return ReferralEarning(
      id: json['id'].toString(),
      amount: double.parse(json['amount']?.toString() ?? '0'),
      source: json['source'] ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
