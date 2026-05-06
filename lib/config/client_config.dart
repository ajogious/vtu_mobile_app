// This file keeps the BrandConfig API surface that all screens depend on,
// but delegates every getter to FlavorConfig.instance — which is set by
// each flavor's entry point (lib/main_<flavor>.dart) at startup.
//
// DO NOT add hardcoded values here. All brand data lives in the flavor
// entry point files (main_a3tech.dart, main_amazcom.dart, etc.).

import '../flavors/flavor_config.dart';

// Kept for backwards compatibility — screens import this file.
// The enum is no longer used for switching; flavor entry points handle that.
enum ClientId { a3tech, amazcom, zamanconcept, azdigital }

class BrandConfig {
  // -------------------------------------------------------------------------
  // All getters delegate to FlavorConfig.instance, which is injected at
  // startup by the active flavor's main_<flavor>.dart entry point.
  // -------------------------------------------------------------------------

  static String get appName       => FlavorConfig.instance.appName;
  static String get apiBaseUrl    => FlavorConfig.instance.baseUrl;
  static String get supportEmail  => FlavorConfig.instance.supportEmail;
  static String get supportPhone  => FlavorConfig.instance.supportPhone;
  static String get supportWhatsApp => FlavorConfig.instance.supportWhatsApp;
  static String get appDownloadLink => FlavorConfig.instance.appDownloadLink;
  static String get tagline       => FlavorConfig.instance.appTagline;
  static String get logoAsset     => FlavorConfig.instance.logoAssetPath;

  // Play Store / App Store links are per-client but not yet finalised.
  // Return a sensible placeholder based on the active flavor's download link.
  static String get playStoreLink => FlavorConfig.instance.appDownloadLink;
  static String get appStoreLink  => FlavorConfig.instance.appDownloadLink;

  // Prevent instantiation.
  BrandConfig._();
}
