import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'config/theme_config.dart';
import 'providers/referral_provider.dart';
import 'providers/app_lock_provider.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/network_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/lock/app_lock_screen.dart';
import 'utils/ui_helpers.dart';

void main() async {
  // Preserve the native splash screen until init is complete —
  // prevents the blank flash between app launch and Flutter rendering.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize services
  await StorageService().init();
  await CacheService.init();
  await NotificationService.init();
  await NotificationService.requestPermissions();

  // Release the native splash — Flutter UI is ready to take over.
  FlutterNativeSplash.remove();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLockProvider()),
        ChangeNotifierProxyProvider<AppLockProvider, AuthProvider>(
          create: (context) => AuthProvider(context.read<AppLockProvider>()),
          update: (_, appLockProvider, authProvider) {
            return authProvider ?? AuthProvider(appLockProvider);
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, authProvider, transactionProvider) {
            transactionProvider!.setAuthProvider(authProvider);
            return transactionProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReferralProvider>(
          create: (_) => ReferralProvider(),
          update: (_, authProvider, referralProvider) {
            referralProvider!.setAuthProvider(authProvider);
            return referralProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, authProvider, notificationProvider) {
            notificationProvider!.setAuthProvider(authProvider);
            return notificationProvider;
          },
        ),
      ],
      child: const VTUApp(),
    );
  }
}

class VTUApp extends StatefulWidget {
  const VTUApp({super.key});

  @override
  State<VTUApp> createState() => _VTUAppState();
}

class _VTUAppState extends State<VTUApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lockProvider = context.read<AppLockProvider>();

    switch (state) {
      case AppLifecycleState.paused:
        lockProvider.onAppBackground();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          lockProvider.onAppForeground();

          authProvider.checkTokenValidity().then((isValid) {
            if (!isValid) {
              authProvider.logout();
            }
          });
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'A3TECH DATA',
          debugShowCheckedModeBanner: false,
          theme: ThemeConfig.lightTheme,
          darkTheme: ThemeConfig.darkTheme,
          themeMode: themeProvider.themeMode,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          builder: (context, child) {
            return Stack(
              children: [?child, _AppLockOverlay()],
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

class _AppLockOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isLocked = context.select<AppLockProvider, bool>((p) => p.isLocked);

    if (!isLocked) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AppLockScreen(
          onUnlocked: () {
            // Dismiss any keyboard from the lock screen before removing the
            // overlay — prevents a floating keyboard over the underlying app.
            FocusManager.instance.primaryFocus?.unfocus();
            context.read<AppLockProvider>().unlock();
          },
        ),
      ),
    );
  }
}
