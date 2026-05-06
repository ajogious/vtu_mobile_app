import 'flavors/client_config.dart';
import 'flavors/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(
    const ClientConfig(
      appName: 'Amazcom',
      baseUrl: 'https://amazcom.com.ng',
      supportEmail: 'support@amazcom.com.ng',
      supportPhone: '+234 816 869 8471',
      supportWhatsApp: '+234 816 869 8471',
      appDownloadLink: 'https://amazcom.com.ng/download',
      appTagline:
          'Buy airtime & data at the best rates, pay bills instantly, and earn while you refer!',
      logoAssetPath: 'images/amazcom/logo.jpg',
      splashColor: '#665ED5',
    ),
  );
  app.mainApp();
}
