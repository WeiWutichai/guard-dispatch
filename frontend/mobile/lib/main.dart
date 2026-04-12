import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/tracking_provider.dart';
import 'services/booking_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/tracking_service.dart';
import 'screens/phone_input_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/role_selection_screen.dart';
import 'services/pin_storage_service.dart';
import 'services/language_service.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required for FCM push notifications)
  await Firebase.initializeApp();

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
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(NotificationService(AuthProvider().apiClient)),
          update: (_, auth, prev) =>
              prev ?? NotificationProvider(NotificationService(auth.apiClient)),
        ),
        ChangeNotifierProvider(
          create: (_) => TrackingProvider(TrackingService()),
        ),
      ],
      child: LanguageProvider(
        notifier: langNotifier,
        child: MaterialApp(
          title: 'P-Guard Mobile',
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
              if (kDebugMode) {
                debugPrint('[MAIN] status=${auth.status} role=${auth.role} isPinSet=${pinService.isPinSet}');
              }
              // Show loading while checking stored auth state.
              if (auth.status == AuthStatus.unknown) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              // PIN gate: any registered user (pending or authenticated) must enter PIN first
              if ((auth.status == AuthStatus.pendingApproval ||
                   auth.status == AuthStatus.authenticated) &&
                  pinService.isPinSet) {
                return PinLockScreen(pinService: pinService);
              }
              // Pending → always go to RoleSelectionScreen.
              // RoleSelectionScreen handles all sub-routing internally:
              // - no role yet → show role picker
              // - has role but pending → RegistrationPendingScreen
              // - approved → dashboard
              if (auth.status == AuthStatus.pendingApproval) {
                return RoleSelectionScreen(phone: auth.phone);
              }
              return const PhoneInputScreen();
            },
          ),
        ),
      ),
    );
  }
}
