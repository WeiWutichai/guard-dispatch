import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/tracking_provider.dart';
import 'services/booking_service.dart';
import 'services/chat_service.dart';
import 'services/tracking_service.dart';
import 'screens/phone_input_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/registration_pending_screen.dart';
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
        Provider<PinStorageService>.value(value: pinService),
        ChangeNotifierProxyProvider<AuthProvider, BookingProvider>(
          create: (_) => BookingProvider(BookingService(AuthProvider().apiClient)),
          update: (_, auth, prev) =>
              prev ?? BookingProvider(BookingService(auth.apiClient)),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(ChatService(AuthProvider().apiClient)),
          update: (_, auth, prev) =>
              prev ?? ChatProvider(ChatService(auth.apiClient)),
        ),
        ChangeNotifierProvider(
          create: (_) => TrackingProvider(TrackingService()),
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
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.status == AuthStatus.pendingApproval) {
                return const RegistrationPendingScreen();
              }
              // PinLockScreen only for users who are fully authenticated.
              // iOS Keychain persists across reinstalls so isPinSet can be true
              // even on a fresh install — only gate authenticated sessions.
              if (auth.status == AuthStatus.authenticated && pinService.isPinSet) {
                return PinLockScreen(pinService: pinService);
              }
              return const PhoneInputScreen();
            },
          ),
        ),
      ),
    );
  }
}
