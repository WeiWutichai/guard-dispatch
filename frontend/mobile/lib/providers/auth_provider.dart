import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

/// Authentication states for the app.
enum AuthStatus {
  /// Haven't checked stored tokens yet.
  unknown,

  /// User is authenticated (has valid access token).
  authenticated,

  /// User is not authenticated.
  unauthenticated,
}

/// Centralized authentication state using ChangeNotifier (Provider pattern).
///
/// Provides:
/// - Current auth status
/// - Login / logout actions
/// - Current user role
/// - Access to the shared ApiClient (with JWT interceptor)
///
/// Usage with Provider:
/// ```dart
/// ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus())
/// ```
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _role;
  final ApiClient _apiClient = ApiClient();

  AuthStatus get status => _status;
  String? get role => _role;
  ApiClient get apiClient => _apiClient;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Check if user has a stored access token on app startup.
  Future<void> checkAuthStatus() async {
    final token = await AuthService.getAccessToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Login as guard with credentials.
  ///
  /// TODO: When backend is ready, call actual API and store tokens.
  Future<bool> loginGuard(String guardId, String password) async {
    final success = await AuthService.loginGuard(guardId, password);
    if (success) {
      _status = AuthStatus.authenticated;
      _role = 'guard';
      notifyListeners();
    }
    return success;
  }

  /// Verify OTP and authenticate.
  ///
  /// TODO: When backend is ready, tokens are stored by AuthService.verifyOtp.
  Future<bool> verifyOtp(String phone, String otp) async {
    final success = await AuthService.verifyOtp(phone, otp);
    if (success) {
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
    return success;
  }

  /// Logout — clear tokens and reset state.
  Future<void> logout() async {
    await AuthService.clearTokens();
    _status = AuthStatus.unauthenticated;
    _role = null;
    notifyListeners();
  }
}
