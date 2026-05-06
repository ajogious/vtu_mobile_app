import '../flavors/flavor_config.dart';

class AppConstants {
  // Brand — sourced from the active flavor config set at app startup
  static String get appName => FlavorConfig.instance.appName;
  static String get supportEmail => FlavorConfig.instance.supportEmail;
  static String get supportPhone => FlavorConfig.instance.supportPhone;
  static String get supportWhatsApp => FlavorConfig.instance.supportWhatsApp;
  static String get appDownloadLink => FlavorConfig.instance.appDownloadLink;
  static String get appTagline => FlavorConfig.instance.appTagline;
  static String get logoAssetPath => FlavorConfig.instance.logoAssetPath;

  static const String appVersion = '1.0.0';

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

  // Data Types per network
  static const List<String> mtnDataTypes = ['SME', 'GIFTING', 'COUPON'];
  static const List<String> gloDataTypes = ['CG'];
  static const List<String> airtelDataTypes = ['CG'];
  static const List<String> nineMobileDataTypes = ['GIFTING'];

  // Amount limits
  static const double minAirtimeAmount = 50;
  static const double maxAirtimeAmount = 10000;
  static const double minElectricityAmount = 1000;
  static const double maxElectricityAmount = 50000;

  // Quick airtime amounts
  static const List<double> quickAirtimeAmounts = [
    50, 100, 200, 500, 1000, 2000, 5000,
  ];

  // PIN
  static const int pinLength = 5;

  // Session
  static const Duration sessionTimeout = Duration(minutes: 30);
}
