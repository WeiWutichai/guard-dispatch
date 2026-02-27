import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/pin_storage_service.dart';
import 'services/language_service.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services before starting the app
  final pinService = await PinStorageService.init();
  final langNotifier = await LanguageNotifier.init();

  runApp(MyApp(pinService: pinService, langNotifier: langNotifier));
}

class MyApp extends StatelessWidget {
  final PinStorageService pinService;
  final LanguageNotifier langNotifier;

  const MyApp({
    super.key,
    required this.pinService,
    required this.langNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
      ],
      child: LanguageProvider(
        notifier: langNotifier,
        child: MaterialApp(
          title: 'SecureGuard Mobile',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.primary,
              surface: AppColors.surface,
            ),
            scaffoldBackgroundColor: AppColors.background,
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
            useMaterial3: true,
          ),
          home: pinService.isPinSet
              ? PinLockScreen(pinService: pinService)
              : PinSetupScreen(pinService: pinService),
        ),
      ),
    );
  }
}
