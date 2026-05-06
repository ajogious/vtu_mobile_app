import 'flavors/client_config.dart';
import 'flavors/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(
    const ClientConfig(
      appName: 'AzDigital',
      baseUrl: 'https://www.azdigital.com.ng',
      supportEmail: 'support@azdigital.com.ng',
      supportPhone: '+234 706 227 3382',
      supportWhatsApp: '+234 706 227 3382',
      appDownloadLink: 'https://www.azdigital.com.ng/download',
      appTagline:
          'Buy airtime & data at the best rates, pay bills instantly, and earn while you refer!',
      logoAssetPath: 'images/azdigital/logo.jpg',
      splashColor: '#665ED5',
    ),
  );
  app.mainApp();
}
