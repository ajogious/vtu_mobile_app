import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize services
  await StorageService().init();
  await CacheService.init();
  await NotificationService.init();
  await NotificationService.requestPermissions();

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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
        // Only record background time on actual pause (not inactive).
        // `inactive` fires when native dialogs (like biometric prompts) appear —
        // treating it as background caused an immediate re-lock after the
        // biometric prompt closed.
        lockProvider.onAppBackground();
        break;
      case AppLifecycleState.inactive:
        // Do nothing — inactive is fired during biometric prompts, phone calls,
        // notification banners, etc. We intentionally don't lock here.
        break;
      case AppLifecycleState.resumed:
        // Only lock when a user session is active — logged-out users on the
        // LoginScreen should never see the AppLockScreen.
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          lockProvider.onAppForeground();
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
          builder: (context, child) {
            return Consumer<AppLockProvider>(
              builder: (context, lockProvider, _) {
                return Stack(
                  children: [
                    if (child != null) child,
                    if (lockProvider.isLocked)
                      Positioned.fill(
                        child: AppLockScreen(
                          onUnlocked: () {
                            lockProvider.unlock();
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
