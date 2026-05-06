import 'flavors/client_config.dart';
import 'flavors/flavor_config.dart';
import 'main.dart' as app;

void main() {
  FlavorConfig.initialize(
    const ClientConfig(
      appName: 'A3TECH DATA',
      baseUrl: 'https://a3tech.com.ng',
      supportEmail: 'support@a3tech.com.ng',
      supportPhone: '+234 813 292 5207',
      supportWhatsApp: '+234 813 292 5207',
      appDownloadLink: 'https://a3tech.com.ng/download',
      appTagline:
          'Buy airtime & data at the best rates, pay bills instantly, and earn while you refer!',
      logoAssetPath: 'images/a3tech/logo.jpg',
      splashColor: '#665ED5',
    ),
  );
  app.mainApp();
}
