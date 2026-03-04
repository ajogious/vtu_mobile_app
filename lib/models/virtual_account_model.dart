class VirtualAccount {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String reference;

  const VirtualAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.reference,
  });

  static List<VirtualAccount> fromApiData(Map<String, dynamic> data) {
    final accountName = data['account_name']?.toString() ?? '';
    final reference = data['reference']?.toString() ?? '';
    final accounts = data['accounts'] as Map<String, dynamic>? ?? {};

    return accounts.entries.map((entry) {
      return VirtualAccount(
        bankName: _formatBankName(entry.key),
        accountNumber: entry.value.toString(),
        accountName: accountName,
        reference: reference,
      );
    }).toList();
  }

  static String _formatBankName(String key) {
    const bankNames = {
      'wema': 'Wema Bank',
      'rolex': 'Moniepoint MFB',
      'sterling': 'Sterling Bank',
      'moniepoint': 'Moniepoint MFB',
      'providus': 'Providus Bank',
      'safe haven': 'Safe Haven MFB',
    };
    return bankNames[key.toLowerCase()] ??
        key[0].toUpperCase() + key.substring(1);
  }
}
