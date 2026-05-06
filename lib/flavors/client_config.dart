/// Holds all brand-specific configuration for a single client.
///
/// Each flavor's entry point (`main_<flavor>.dart`) instantiates one of these
/// and hands it to [FlavorConfig.initialize] before the app starts.
class ClientConfig {
  /// Display name shown in the app title bar and throughout the UI.
  final String appName;

  /// Root domain for this client, e.g. "https://a3tech.com.ng".
  /// ApiConfig will append "/api/app/v1" to form the full base URL.
  final String baseUrl;

  /// Customer-facing support e-mail address.
  final String supportEmail;

  /// Customer-facing support phone number (E.164 format preferred).
  final String supportPhone;

  /// WhatsApp number used to open wa.me deep-links.
  final String supportWhatsApp;

  /// Link shown on the "Download App" / referral share screen.
  final String appDownloadLink;

  /// Short marketing tagline shown on the splash / onboarding screen.
  final String appTagline;

  /// Path to the client's logo inside the Flutter asset bundle.
  /// Example: "images/amazcom/logo.jpg"
  final String logoAssetPath;

  /// Hex splash-screen background colour string (used by native splash).
  /// Example: "#665ED5"
  final String splashColor;

  const ClientConfig({
    required this.appName,
    required this.baseUrl,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportWhatsApp,
    required this.appDownloadLink,
    required this.appTagline,
    required this.logoAssetPath,
    required this.splashColor,
  });
}
