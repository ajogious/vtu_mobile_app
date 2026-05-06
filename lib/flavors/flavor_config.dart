import 'client_config.dart';

/// Singleton that stores the active [ClientConfig] for the current build flavor.
///
/// Must be initialized **once** at the very start of each flavor's entry point
/// (`main_<flavor>.dart`) before [mainApp] is called.
///
/// Usage:
/// ```dart
/// // In main_amazcom.dart:
/// FlavorConfig.initialize(ClientConfig(appName: 'Amazcom', ...));
/// mainApp();
///
/// // Anywhere in the app:
/// final name = FlavorConfig.instance.appName;
/// ```
class FlavorConfig {
  static ClientConfig? _instance;

  /// The active client config. Throws a clear error if accessed before
  /// [initialize] is called, making misconfiguration easy to catch in dev.
  static ClientConfig get instance {
    assert(
      _instance != null,
      'FlavorConfig.initialize() must be called before accessing FlavorConfig.instance. '
      'Make sure you are running the app via a flavor entry point '
      '(e.g. lib/main_a3tech.dart) and not lib/main.dart directly.',
    );
    return _instance!;
  }

  /// Call this once from your flavor's entry-point file before [mainApp].
  static void initialize(ClientConfig config) {
    _instance = config;
  }

  // Prevent instantiation.
  FlavorConfig._();
}
