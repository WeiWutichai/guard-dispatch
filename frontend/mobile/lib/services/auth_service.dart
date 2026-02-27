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
  /// TODO: Replace with real API call to POST /auth/request-otp
  /// when backend OTP endpoint is implemented.
  static Future<bool> requestOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // TODO: Replace with actual API call:
    // final response = await dio.post('/auth/request-otp', data: {'phone': phone});
    // return response.statusCode == 200;

    if (phone.isEmpty) return false;
    return true;
  }

  /// Verify OTP code against server.
  ///
  /// TODO: Replace with real API call to POST /auth/verify-otp
  /// when backend OTP endpoint is implemented.
  static Future<bool> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with actual API call:
    // final response = await dio.post('/auth/verify-otp', data: {
    //   'phone': phone,
    //   'otp': otp,
    // });
    // if (response.statusCode == 200) {
    //   await storeTokens(response.data['access_token'], response.data['refresh_token']);
    //   return true;
    // }
    // return false;

    // Prototype: accept any 6-digit OTP (no hardcoded value in source)
    if (otp.length != 6) return false;
    return true;
  }

  /// Authenticate guard with the backend auth service.
  ///
  /// TODO: Replace with real API call to POST /auth/login when
  /// dio/http dependency is added. Currently validates non-empty
  /// credentials and simulates a network call for prototype.
  static Future<bool> loginGuard(String guardId, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with actual API call:
    // final response = await dio.post('/auth/login', data: {
    //   'guard_id': guardId,
    //   'password': password,
    // });
    // if (response.statusCode == 200) {
    //   await _storeTokens(response.data['access_token'], response.data['refresh_token']);
    //   return true;
    // }
    // return false;

    // Prototype: reject empty credentials, accept any non-empty pair
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
