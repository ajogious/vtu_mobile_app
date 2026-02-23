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
      source: json['description'] ?? '', // API returns "description"
      transactionId: json['ref'] ?? '', // API returns "ref"
      createdAt: _parseDate(json['date']), // API returns "date"
    );
  }

  // Handles API format: "29-12-2023 09:24:07 PM"
  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
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
}
