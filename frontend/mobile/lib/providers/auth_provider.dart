import 'dart:io';

import 'package:dio/dio.dart';
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

  /// User has registered but is waiting for admin approval.
  /// No tokens are stored — login is blocked until approved.
  pendingApproval,
}

/// Centralized authentication state using ChangeNotifier (Provider pattern).
///
/// Provides:
/// - Current auth status
/// - Login / logout actions
/// - OTP request, verify, and register flows
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
  String? _fullName;
  String? _phone;
  String? _avatarUrl;
  final ApiClient _apiClient = ApiClient();

  AuthStatus get status => _status;
  String? get role => _role;
  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get avatarUrl => _avatarUrl;
  ApiClient get apiClient => _apiClient;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isPendingApproval => _status == AuthStatus.pendingApproval;

  /// Check persisted auth state on app startup.
  ///
  /// Priority: pendingApproval flag > stored access token > unauthenticated.
  Future<void> checkAuthStatus() async {
    if (await AuthService.isPendingApproval()) {
      _status = AuthStatus.pendingApproval;
      _role = await AuthService.getPendingRole();
      notifyListeners();
      return;
    }
    final token = await AuthService.getAccessToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
      _role = await AuthService.getRole();
      notifyListeners();
      await fetchProfile();
      return;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Fetch the authenticated user's profile from GET /auth/me.
  Future<void> fetchProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      final data = response.data['data'];
      _fullName = data['full_name'] as String?;
      _phone = data['phone'] as String?;
      _avatarUrl = data['avatar_url'] as String?;
      notifyListeners();
    } catch (_) {
      // Silently fail — dashboard will show fallback values.
    }
  }

  /// Request OTP from the backend for phone verification.
  ///
  /// Calls POST /auth/otp/request with the phone number.
  /// Throws [DioException] on network error or server-side rate limiting.
  Future<void> requestOtp(String phone) async {
    await _apiClient.dio.post('/auth/otp/request', data: {'phone': phone});
  }

  /// Verify OTP code against the backend.
  ///
  /// Calls POST /auth/otp/verify and returns a temporary `phone_verified_token`
  /// that must be used in the registration step.
  /// Throws [DioException] on invalid OTP or network error.
  Future<String> verifyOtp(String phone, String code) async {
    final response = await _apiClient.dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
    });
    return response.data['data']['phone_verified_token'] as String;
  }

  /// Register a new account using a verified phone token.
  ///
  /// Calls POST /auth/register/otp. On success (HTTP 202) the account is
  /// created with `pending` approval status — no tokens are issued. The user
  /// must wait for admin approval before they can log in.
  ///
  /// Returns a `profile_token` for guard registrations (non-null) that must be
  /// used immediately to submit guard profile data via [submitGuardProfile].
  /// Returns null for non-guard registrations.
  ///
  /// [role] is optional. When null the account is created without a role
  /// ("ยังไม่ได้ระบุ" in admin UI) until the user selects one during onboarding.
  Future<String?> registerWithOtp({
    required String phoneVerifiedToken,
    String? password,
    String? fullName,
    String? email,
    String? role,
  }) async {
    final data = <String, dynamic>{
      'phone_verified_token': phoneVerifiedToken,
    };
    if (role != null) data['role'] = role;
    if (password != null) data['password'] = password;
    if (fullName != null) data['full_name'] = fullName;
    if (email != null) data['email'] = email;

    final response = await _apiClient.dio.post('/auth/register/otp', data: data);

    // Persist pending state so the correct screen shows on app restart.
    await AuthService.setPendingApproval(role: role);
    _status = AuthStatus.pendingApproval;
    _role = role;
    notifyListeners();

    // Return the profile_token for guard registrations (null for other roles).
    final raw = response.data['data']?['profile_token'];
    return raw is String ? raw : null;
  }

  /// Reissue a profile_token for a pending user who already passed OTP.
  /// Used when retrying profile submission without repeating the OTP flow.
  /// [role] determines the token purpose (guard_profile or customer_profile).
  Future<String> reissueProfileToken(String phone, {String? role}) async {
    final response = await _apiClient.dio.post(
      '/auth/profile/reissue',
      data: <String, dynamic>{'phone': phone, if (role != null) 'role': role},
    );
    final token = response.data['data']?['profile_token'];
    if (token is! String) {
      throw Exception('Failed to reissue profile token');
    }
    return token;
  }

  /// Set the role of a pending user (step 2 of 3-step registration).
  /// Calls POST /auth/profile/role with phone + role.
  /// Returns profile_token for guard role (null for customer).
  Future<String?> updateRole(String phone, String role) async {
    final response = await _apiClient.dio.post(
      '/auth/profile/role',
      data: {'phone': phone, 'role': role},
    );

    // Update local pending state with the chosen role
    await AuthService.setPendingApproval(role: role);
    _role = role;
    notifyListeners();

    // Return profile_token for guard (null for customer)
    final raw = response.data['data']?['profile_token'];
    return raw is String ? raw : null;
  }

  /// Submit guard profile data after registration.
  ///
  /// Calls POST /auth/profile/guard with multipart form data.
  /// Requires the [profileToken] returned by [registerWithOtp] for guard role.
  /// [files] maps document field name to the picked image file:
  ///   "id_card", "security_license", "training_cert", "criminal_check",
  ///   "driver_license", "passbook_photo"
  Future<void> submitGuardProfile({
    required String profileToken,
    String? fullName,
    String? gender,
    String? dateOfBirth,
    int? yearsOfExperience,
    String? previousWorkplace,
    String? bankName,
    String? accountNumber,
    String? accountName,
    Map<String, File> files = const {},
  }) async {
    final formData = FormData();

    if (fullName != null) formData.fields.add(MapEntry('full_name', fullName));
    if (gender != null) formData.fields.add(MapEntry('gender', gender));
    if (dateOfBirth != null) formData.fields.add(MapEntry('date_of_birth', dateOfBirth));
    if (yearsOfExperience != null) {
      formData.fields.add(MapEntry('years_of_experience', yearsOfExperience.toString()));
    }
    if (previousWorkplace != null) {
      formData.fields.add(MapEntry('previous_workplace', previousWorkplace));
    }
    if (bankName != null) formData.fields.add(MapEntry('bank_name', bankName));
    if (accountNumber != null) formData.fields.add(MapEntry('account_number', accountNumber));
    if (accountName != null) formData.fields.add(MapEntry('account_name', accountName));

    for (final entry in files.entries) {
      formData.files.add(MapEntry(
        entry.key,
        await MultipartFile.fromFile(entry.value.path),
      ));
    }

    await _apiClient.dio.post(
      '/auth/profile/guard',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $profileToken'}),
    );
  }

  /// Submit customer profile data after registration.
  ///
  /// Calls POST /auth/profile/customer with JSON body.
  /// Requires the [profileToken] returned by [updateRole] for customer role.
  Future<void> submitCustomerProfile({
    required String profileToken,
    required String address,
    String? fullName,
    String? contactPhone,
    String? email,
    String? companyName,
  }) async {
    await _apiClient.dio.post(
      '/auth/profile/customer',
      data: <String, dynamic>{
        'address': address,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (companyName != null && companyName.isNotEmpty) 'company_name': companyName,
      },
      options: Options(headers: {'Authorization': 'Bearer $profileToken'}),
    );
  }

  /// Login with phone + PIN hash after admin approval.
  ///
  /// Calls POST /auth/login/phone with phone number and the SHA-256 hashed PIN
  /// (which was stored as the password during registration).
  /// On success: stores tokens + role, clears pending state, sets authenticated.
  Future<bool> loginWithPhone(String phone, String pinHash) async {
    final response = await _apiClient.dio.post('/auth/login/phone', data: {
      'phone': phone,
      'password': pinHash,
    });
    final data = response.data['data'];
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final role = data['role'] as String;

    await Future.wait([
      AuthService.storeTokens(accessToken, refreshToken),
      AuthService.storeRole(role),
      AuthService.clearPendingApproval(),
    ]);

    _status = AuthStatus.authenticated;
    _role = role;
    notifyListeners();
    await fetchProfile();
    return true;
  }

  /// Logout — clear tokens, pending state, and reset auth status.
  Future<void> logout() async {
    await Future.wait([
      AuthService.clearTokens(),
      AuthService.clearPendingApproval(),
      AuthService.clearRole(),
    ]);
    _status = AuthStatus.unauthenticated;
    _role = null;
    _fullName = null;
    _phone = null;
    _avatarUrl = null;
    notifyListeners();
  }

  /// Clear all registration data so the user can re-apply from scratch.
  /// Does NOT call a backend endpoint — only wipes local state.
  Future<void> restartRegistration() async {
    await AuthService.clearAllRegistrationData();
    _status = AuthStatus.unauthenticated;
    _role = null;
    notifyListeners();
  }
}
