class ApiConfig {
  // Base URL (LIVE - use this for production)
  static const String liveBaseUrl = 'https://a3tech.com.ng';

  // API version path
  static const String apiPath = '/api/app/v1';

  // Full base URL
  static String get baseUrl => '$liveBaseUrl$apiPath';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth endpoints
  static const String loginEndpoint = '/auth/login.php';
  static const String registerEndpoint = '/auth/register.php';
  static const String forgotPasswordEndpoint = '/auth/forgot-password.php';
  static const String verifyOtpEndpoint = '/auth/verify-otp.php';
  static const String resetPasswordEndpoint = '/auth/reset-password.php';

  // User endpoints
  static const String userProfileEndpoint = '/user/me.php';
  static const String logoutEndpoint = '/user/logout.php';
  static const String changePasswordEndpoint = '/user/change-password.php';
  static const String updateProfileEndpoint = '/user/update-profile.php';
  static const String setPinEndpoint = '/user/set-pin.php';
  static const String changePinEndpoint = '/user/change-pin.php';

  // Plans endpoints
  static const String dataPlansEndpoint = '/plans/data.php';
  static const String airtimePlansEndpoint = '/plans/airtime.php';
  static const String cablePlansEndpoint = '/plans/cable.php';
  static const String electricPlansEndpoint = '/plans/electric.php';
  static const String examPlansEndpoint = '/plans/exam.php';
  static const String datacardPlansEndpoint = '/plans/datacard.php';

  // Purchase endpoints
  static const String buyDataEndpoint = '/buy/data.php';
  static const String buyAirtimeEndpoint = '/buy/airtime.php';
  static const String buyCableEndpoint = '/buy/cable.php';
  static const String buyElectricEndpoint = '/buy/electric.php';
  static const String buyExamEndpoint = '/buy/exam.php';
  static const String buyDatacardEndpoint = '/buy/datacard.php';

  // Transaction endpoints
  static const String transactionsEndpoint = '/transactions/list.php';
  static const String transactionDetailEndpoint = '/transactions/detail.php';

  // Referral endpoints
  static const String referralHistoryEndpoint = '/referral/history.php';

  // ATC endpoint
  static const String atcRequestEndpoint = '/airtime_to_cash/request.php';

  // Headers
  static Map<String, String> headers({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
