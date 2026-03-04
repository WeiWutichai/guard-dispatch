import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyPrefix = 'registered_';
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyVerifiedPhone = 'verified_phone';
  static const _keyPhoneVerifiedToken = 'phone_verified_token';
  static const _keyPendingApproval = 'pending_approval';
  static const _keyPendingRole = 'pending_role';

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

  // ---------------------------------------------------------------------------
  // Pending approval state (non-sensitive — SharedPreferences is appropriate)
  // ---------------------------------------------------------------------------

  static Future<bool> isPendingApproval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPendingApproval) ?? false;
  }

  static Future<void> setPendingApproval({String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingApproval, true);
    if (role != null) {
      await prefs.setString(_keyPendingRole, role);
    } else {
      await prefs.remove(_keyPendingRole);
    }
  }

  static Future<String?> getPendingRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPendingRole);
  }

  static Future<void> clearPendingApproval() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingApproval);
    await prefs.remove(_keyPendingRole);
  }

  /// Store phone + phoneVerifiedToken after OTP verification.
  /// Used as fallback when RoleSelectionScreen doesn't receive them directly.
  static Future<void> storePhoneVerifiedData(String phone, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVerifiedPhone, phone);
    await _secureStorage.write(key: _keyPhoneVerifiedToken, value: token);
  }

  /// Retrieve stored phone + phoneVerifiedToken.
  static Future<(String?, String?)> getPhoneVerifiedData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyVerifiedPhone);
    final token = await _secureStorage.read(key: _keyPhoneVerifiedToken);
    return (phone, token);
  }

  /// Clear stored phone verified data (after registration completes).
  static Future<void> clearPhoneVerifiedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVerifiedPhone);
    await _secureStorage.delete(key: _keyPhoneVerifiedToken);
  }

  // ---------------------------------------------------------------------------
  // Pending profile summary (shown on RegistrationPendingScreen)
  // ---------------------------------------------------------------------------

  static const _keyPendingProfileJson = 'pending_profile_json';

  /// Save submitted guard profile fields locally so they can be displayed
  /// on [RegistrationPendingScreen] without an authenticated API call.
  static Future<void> savePendingProfile(Map<String, String?> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingProfileJson, jsonEncode(data));
  }

  /// Retrieve locally saved profile summary. Returns null if not set.
  static Future<Map<String, dynamic>?> getPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingProfileJson);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clearPendingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingProfileJson);
  }

  /// Clear all registration-related state so the user can start over.
  /// Called from RegistrationPendingScreen "สมัครใหม่" action.
  static Future<void> clearAllRegistrationData() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      // Pending approval + role
      prefs.remove(_keyPendingApproval),
      prefs.remove(_keyPendingRole),
      // Locally saved profile summary
      prefs.remove(_keyPendingProfileJson),
      // Phone verified data (SharedPreferences part)
      prefs.remove(_keyVerifiedPhone),
      // Phone verified token (secure storage)
      _secureStorage.delete(key: _keyPhoneVerifiedToken),
      // Access / refresh tokens (likely null in pending state, clear anyway)
      _secureStorage.delete(key: _keyAccessToken),
      _secureStorage.delete(key: _keyRefreshToken),
    ]);
  }
}
