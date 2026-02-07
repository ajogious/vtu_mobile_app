class VirtualAccount {
  final String bankName;
  final String accountNumber;
  final String accountName;

  VirtualAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory VirtualAccount.fromJson(Map<String, dynamic> json) {
    return VirtualAccount(
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountName: json['account_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
    };
  }
}
