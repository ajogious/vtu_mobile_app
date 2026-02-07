class AppConstants {
  // App Info
  static const String appName = 'A3TECH DATA';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@a3tech.com.ng';
  static const String supportPhone = '+234 813 292 5207';
  static const String supportWhatsApp = '+234 813 292 5207';

  // Wallet
  static const double minFundingAmount = 100.0;
  static const double maxFundingAmount = 1000000.0;
  static const double lowBalanceThreshold = 500.0;
  static const double minWithdrawalAmount = 500.0;

  // Transactions
  static const int transactionsPerPage = 10;
  static const double largeTransactionThreshold = 10000.0;

  // Networks
  static const List<String> networks = ['MTN', 'GLO', 'AIRTEL', '9MOBILE'];

  // Exam Types
  static const List<String> examTypes = ['WAEC', 'NECO', 'NABTEB'];

  // Cable Providers
  static const List<String> cableProviders = ['DSTV', 'GOTV', 'STARTIMES'];

  // DISCOs
  static const List<String> discos = [
    'EKEDC',
    'IKEDC',
    'AEDC',
    'PHED',
    'IBEDC',
    'KEDCO',
    'EEDC',
    'JEDC',
  ];

  // Data Types
  static const List<String> mtnDataTypes = ['SME', 'GIFTING', 'COUPON'];
  static const List<String> gloDataTypes = ['CG'];
  static const List<String> airtelDataTypes = ['CG'];
  static const List<String> nineMobileDataTypes = ['GIFTING'];

  // Quick Airtime Amounts
  static const List<double> quickAirtimeAmounts = [
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
  ];

  // PIN
  static const int pinLength = 5;

  // Session
  static const Duration sessionTimeout = Duration(minutes: 30);
}
