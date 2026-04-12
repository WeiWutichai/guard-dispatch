import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Store the user's phone number (persisted across app restarts) in secure
  /// storage. Phone numbers are PII under Thailand's PDPA; keeping them out
  /// of SharedPreferences prevents Android Auto Backup from uploading them
  /// to Google Drive in plaintext. (security-reviewer MEDIUM M2)
  static Future<void> storePhone(String phone) async {
    await _secureStorage.write(key: _keyPhone, value: phone);
    // Transparent migration: if a legacy SharedPreferences entry exists
    // from a previous app version, delete it so the plaintext copy doesn't
    // linger on disk / in cloud backups.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyPhone)) {
      await prefs.remove(_keyPhone);
    }
  }

  /// Retrieve stored phone number. Falls back to the legacy SharedPreferences
  /// location for a single migration cycle so users upgrading don't lose it.
  static Future<String?> getStoredPhone() async {
    final secure = await _secureStorage.read(key: _keyPhone);
    if (secure != null) {
      if (kDebugMode) debugPrint('[AuthService] getStoredPhone: found in SecureStorage');
      return secure;
    }
    // Legacy fallback — migrate on read.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_keyPhone);
    if (legacy != null) {
      if (kDebugMode) debugPrint('[AuthService] getStoredPhone: migrating from SharedPreferences');
      await _secureStorage.write(key: _keyPhone, value: legacy);
      await prefs.remove(_keyPhone);
      return legacy;
    }
    if (kDebugMode) debugPrint('[AuthService] getStoredPhone: NOT FOUND');
    return null;
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
  /// Both values live in secure storage — phone is PII under PDPA.
  /// (security-reviewer MEDIUM M2)
  static Future<void> storePhoneVerifiedData(String phone, String token) async {
    await _secureStorage.write(key: _keyVerifiedPhone, value: phone);
    await _secureStorage.write(key: _keyPhoneVerifiedToken, value: token);
    // Clean up any legacy plaintext entry from older app versions.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyVerifiedPhone)) {
      await prefs.remove(_keyVerifiedPhone);
    }
  }

  /// Retrieve stored phone + phoneVerifiedToken. Migrates legacy plaintext
  /// entries into secure storage on first read after the upgrade.
  static Future<(String?, String?)> getPhoneVerifiedData() async {
    String? phone = await _secureStorage.read(key: _keyVerifiedPhone);
    if (phone == null) {
      // Legacy fallback — migrate on read.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_keyVerifiedPhone);
      if (legacy != null) {
        phone = legacy;
        await _secureStorage.write(key: _keyVerifiedPhone, value: legacy);
        await prefs.remove(_keyVerifiedPhone);
      }
    }
    final token = await _secureStorage.read(key: _keyPhoneVerifiedToken);
    return (phone, token);
  }

  /// Clear stored phone verified data (after registration completes).
  static Future<void> clearPhoneVerifiedData() async {
    await _secureStorage.delete(key: _keyVerifiedPhone);
    await _secureStorage.delete(key: _keyPhoneVerifiedToken);
    // Legacy cleanup — old builds wrote the phone to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyVerifiedPhone)) {
      await prefs.remove(_keyVerifiedPhone);
    }
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
      // Pending approval + role (SharedPreferences)
      prefs.remove(_keyPendingApproval),
      prefs.remove(_keyPendingRole),
      // Authenticated role (SharedPreferences — not PII)
      prefs.remove(_keyRole),
      // Locally saved profile summary (SharedPreferences — masked)
      prefs.remove(_keyPendingProfileJson),
      prefs.remove(_keyPendingProfileGuard),
      prefs.remove(_keyPendingProfileCustomer),
      // Legacy plaintext phone entries (from pre-M2 builds). Safe to remove
      // unconditionally — the secure-storage version is the source of truth.
      prefs.remove(_keyPhone),
      prefs.remove(_keyVerifiedPhone),
      // Phone (PII) — now in secure storage
      _secureStorage.delete(key: _keyPhone),
      _secureStorage.delete(key: _keyVerifiedPhone),
      _secureStorage.delete(key: _keyPhoneVerifiedToken),
      // Access / refresh tokens
      _secureStorage.delete(key: _keyAccessToken),
      _secureStorage.delete(key: _keyRefreshToken),
    ]);
  }
}
