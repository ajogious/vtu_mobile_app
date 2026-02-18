import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme_config.dart';
import 'providers/referral_provider.dart';
import 'providers/app_lock_provider.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/network_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/lock/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await StorageService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
        ChangeNotifierProvider(create: (_) => AppLockProvider()),
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
      case AppLifecycleState.inactive:
        lockProvider.onAppBackground();
        break;
      case AppLifecycleState.resumed:
        lockProvider.onAppForeground();
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
          title: 'A3TECH VTU APP',
          debugShowCheckedModeBanner: false,
          theme: ThemeConfig.lightTheme,
          darkTheme: ThemeConfig.darkTheme,
          themeMode: themeProvider.themeMode,
          home: Consumer<AppLockProvider>(
            builder: (context, lockProvider, child) {
              if (lockProvider.isLocked) {
                return AppLockScreen(
                  onUnlocked: () {
                    lockProvider.unlock();
                  },
                );
              }
              return child!;
            },
            child: const SplashScreen(),
          ),
        );
      },
    );
  }
}
