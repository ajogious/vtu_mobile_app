import 'flavors/client_config.dart';
import 'flavors/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(
    const ClientConfig(
      appName: 'ZamanConcept',
      baseUrl: 'https://zamanconcept.com.ng',
      supportEmail: 'support@zamanconcept.com.ng',
      supportPhone: '+234 703 603 1804',
      supportWhatsApp: '+234 703 603 1804',
      appDownloadLink: 'https://zamanconcept.com.ng/download',
      appTagline:
          'Buy airtime & data at the best rates, pay bills instantly, and earn while you refer!',
      logoAssetPath: 'images/zamanconcept/logo.jpg',
      splashColor: '#665ED5',
    ),
  );
  app.mainApp();
}
