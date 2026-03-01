import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyPrefix = 'registered_';
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<bool> isRegistered(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$role') ?? false;
  }

  static Future<void> markRegistered(String role, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$role', true);
    await prefs.setString('phone_$role', phone);
  }

  static Future<String?> getPhone(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('phone_$role');
  }

  /// Request OTP from server for phone number verification.
  ///
  /// SECURITY WARNING: This is a STUB — does NOT call the backend.
  /// MUST be replaced with real API call before production deployment.
  /// See: POST /auth/request-otp
  // ignore: todo
  // TODO(CRITICAL-SECURITY): Replace stub with real API call via ApiClient
  static Future<bool> requestOtp(String phone) async {
    assert(() {
      // ignore: avoid_print
      print('[SECURITY] requestOtp is a STUB — not calling backend!');
      return true;
    }());

    await Future.delayed(const Duration(milliseconds: 500));

    // STUB: Replace with actual API call:
    // final response = await apiClient.dio.post('/auth/request-otp', data: {'phone': phone});
    // return response.statusCode == 200;

    if (phone.isEmpty) return false;
    return true;
  }

  /// Verify OTP code against server.
  ///
  /// SECURITY WARNING: This is a STUB — accepts ANY 6-digit OTP without
  /// server verification. MUST be replaced before production deployment.
  /// See: POST /auth/verify-otp
  // ignore: todo
  // TODO(CRITICAL-SECURITY): Replace stub with real API call via ApiClient
  static Future<bool> verifyOtp(String phone, String otp) async {
    assert(() {
      // ignore: avoid_print
      print('[SECURITY] verifyOtp is a STUB — accepts any 6-digit OTP!');
      return true;
    }());

    await Future.delayed(const Duration(milliseconds: 800));

    // STUB: Replace with actual API call:
    // final response = await apiClient.dio.post('/auth/verify-otp', data: {
    //   'phone': phone,
    //   'otp': otp,
    // });
    // if (response.statusCode == 200) {
    //   await storeTokens(response.data['access_token'], response.data['refresh_token']);
    //   return true;
    // }
    // return false;

    // STUB: accept any 6-digit OTP (no hardcoded value in source)
    if (otp.length != 6) return false;
    return true;
  }

  /// Authenticate guard with the backend auth service.
  ///
  /// SECURITY WARNING: This is a STUB — accepts ANY non-empty credentials
  /// without server verification. MUST be replaced before production.
  /// See: POST /auth/login
  // ignore: todo
  // TODO(CRITICAL-SECURITY): Replace stub with real API call via ApiClient
  static Future<bool> loginGuard(String guardId, String password) async {
    assert(() {
      // ignore: avoid_print
      print('[SECURITY] loginGuard is a STUB — accepts any credentials!');
      return true;
    }());

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // STUB: Replace with actual API call:
    // final response = await apiClient.dio.post('/auth/login', data: {
    //   'guard_id': guardId,
    //   'password': password,
    // });
    // if (response.statusCode == 200) {
    //   await storeTokens(response.data['access_token'], response.data['refresh_token']);
    //   return true;
    // }
    // return false;

    // STUB: reject empty credentials, accept any non-empty pair
    if (guardId.isEmpty || password.isEmpty) return false;
    return true;
  }

  /// Store JWT tokens securely (for future API integration).
  static Future<void> storeTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  /// Retrieve stored access token.
  static Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _keyAccessToken);
  }

  /// Retrieve stored refresh token.
  static Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _keyRefreshToken);
  }

  /// Clear all auth tokens (logout).
  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
  }
}
