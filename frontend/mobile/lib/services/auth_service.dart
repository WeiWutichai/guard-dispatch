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
  static const _keyRole = 'user_role';
  static const _keyPhone = 'user_phone';

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

  /// Store JWT tokens securely.
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
  // Role & phone storage (non-sensitive — SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Store the authenticated user's role after successful login.
  static Future<void> storeRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  /// Retrieve stored user role.
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  /// Clear stored role (on logout).
  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
  }

  /// Store the user's phone number (persisted across app restarts).
  static Future<void> storePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
  }

  /// Retrieve stored phone number.
  static Future<String?> getStoredPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
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
      // Append role to set (supports both guard + customer pending)
      final existing = prefs.getString(_keyPendingRole) ?? '';
      final roles = existing.split(',').where((r) => r.isNotEmpty).toSet();
      roles.add(role);
      await prefs.setString(_keyPendingRole, roles.join(','));
    }
  }

  /// Returns the first pending role, or null.
  static Future<String?> getPendingRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingRole);
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').first;
  }

  /// Check if a specific role has been submitted.
  static Future<bool> hasSubmittedRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingRole) ?? '';
    return raw.split(',').contains(role);
  }

  static Future<void> clearPendingApproval() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingApproval);
    await prefs.remove(_keyPendingRole);
    await prefs.remove(_keyPendingProfileJson);
    await prefs.remove(_keyPendingProfileGuard);
    await prefs.remove(_keyPendingProfileCustomer);
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
  static const _keyPendingProfileGuard = 'pending_profile_guard';
  static const _keyPendingProfileCustomer = 'pending_profile_customer';

  /// Save submitted profile fields locally, keyed by role.
  static Future<void> savePendingProfile(Map<String, String?> data) async {
    final prefs = await SharedPreferences.getInstance();
    final role = data['role'] ?? '';
    final json = jsonEncode(data);
    // Save role-specific + legacy key for backward compat
    await prefs.setString(_keyPendingProfileJson, json);
    if (role == 'guard') {
      await prefs.setString(_keyPendingProfileGuard, json);
    } else if (role == 'customer') {
      await prefs.setString(_keyPendingProfileCustomer, json);
    }
  }

  /// Retrieve profile for a specific role.
  static Future<Map<String, dynamic>?> getPendingProfileForRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'guard' ? _keyPendingProfileGuard : _keyPendingProfileCustomer;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Retrieve locally saved profile summary (legacy — returns last saved).
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
      // Authenticated role + phone
      prefs.remove(_keyRole),
      prefs.remove(_keyPhone),
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
