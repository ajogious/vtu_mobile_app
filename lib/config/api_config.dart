class ApiConfig {
  // Change this to switch between mock and real API
  static const Environment currentEnvironment = Environment.mock;

  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.mock:
        return 'http://mock.local'; // Not actually used
      case Environment.production:
        return 'https://a3tech.com.ng/api'; // Your live API
    }
  }

  static bool get isMock => currentEnvironment == Environment.mock;
  static bool get isProduction => currentEnvironment == Environment.production;

  // API Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

enum Environment { mock, production }
