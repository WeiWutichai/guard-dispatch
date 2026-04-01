import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  bool _isCheckingAuth = false;
  String? _userId;
  String? _role;
  String? _fullName;
  String? _phone;
  String? _avatarUrl;
  String? _email;
  String? _approvalStatus;
  String? _createdAt;
  String? _companyName;
  String? _contactPhone;
  // Guard profile fields
  String? _gender;
  String? _dateOfBirth;
  int? _yearsOfExperience;
  String? _previousWorkplace;
  // Guard document URLs + expiry dates (from /auth/guards/{id}/profile)
  Map<String, String?> _guardDocUrls = {};
  Map<String, String?> _guardDocExpiry = {};
  bool _docsLoaded = false;
  String? _customerFullName;
  String? _customerApprovalStatus;
  String? _customerAddress;
  final ApiClient _apiClient = ApiClient();

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get role => _role;
  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get avatarUrl => _avatarUrl;
  String? get email => _email;
  String? get approvalStatus => _approvalStatus;
  String? get createdAt => _createdAt;
  String? get companyName => _companyName;
  String? get contactPhone => _contactPhone;
  String? get gender => _gender;
  String? get dateOfBirth => _dateOfBirth;
  int? get yearsOfExperience => _yearsOfExperience;
  String? get previousWorkplace => _previousWorkplace;
  Map<String, String?> get guardDocUrls => _guardDocUrls;
  Map<String, String?> get guardDocExpiry => _guardDocExpiry;
  bool get docsLoaded => _docsLoaded;
  /// Customer-only: full name from customer_profiles (may differ from guard name).
  String? get customerFullName => _customerFullName;
  /// Customer profile approval status (from customer_profiles.approval_status).
  /// null = no customer profile submitted, 'pending'/'approved'/'rejected'.
  String? get customerAddress => _customerAddress;
  String? get customerApprovalStatus => _customerApprovalStatus;
  ApiClient get apiClient => _apiClient;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isPendingApproval => _status == AuthStatus.pendingApproval;

  /// Check persisted auth state on app startup.
  ///
  /// If valid tokens exist they take priority (user is already approved).
  /// Only fall back to pendingApproval when there are no tokens.
  Future<void> checkAuthStatus() async {
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;
    try {
      await _checkAuthStatusImpl();
    } finally {
      _isCheckingAuth = false;
    }
  }

  Future<void> _checkAuthStatusImpl() async {
    final token = await AuthService.getAccessToken();
    if (token != null) {
      // User has tokens — they are authenticated regardless of any stale
      // pending flag (e.g. an approved guard who added a customer profile).
      if (await AuthService.isPendingApproval()) {
        await AuthService.clearPendingApproval();
      }
      _role = await AuthService.getRole();
      final profileOk = await fetchProfile();
      // Re-check tokens — interceptor may have cleared them on 401 + refresh failure
      final stillHasToken = await AuthService.getAccessToken();
      if (stillHasToken == null) {
        // Tokens were cleared by interceptor (401 + refresh failure) — truly unauthenticated
        debugPrint('[AuthProvider] tokens cleared after fetchProfile, falling back to unauthenticated');
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      // Tokens still valid — user is authenticated even if profile fetch failed
      // (e.g. network timeout, backend down). Profile data will load on next app open.
      if (!profileOk) {
        debugPrint('[AuthProvider] fetchProfile failed but tokens still valid, treating as authenticated');
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // No token — check if user has pending registration via backend API.
    // This is the source of truth (not SharedPreferences which can be stale).
    final phone = await AuthService.getStoredPhone();
    if (phone != null) {
      try {
        const secureStorage = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );
        final pinHash = await secureStorage.read(key: 'pin_hash');
        debugPrint('[AuthProvider] checkAuth: phone=$phone, hasPinHash=${pinHash != null}');

        if (pinHash != null) {
          // Single API call: check-status first, then login only if approved.
          // This avoids 2 round-trips (login fail + check-status).
          try {
            final response = await _apiClient.dio.post(
              '/auth/check-status',
              data: {'phone': phone, 'password': pinHash},
            );
            final data = response.data['data'];
            if (data != null && data['exists'] == true) {
              final dbRole = data['role'] as String?;
              final hasGuardProfile = data['has_guard_profile'] == true;
              final hasCustomerProfile = data['has_customer_profile'] == true;
              debugPrint('[AuthProvider] check-status: role=$dbRole guard=$hasGuardProfile customer=$hasCustomerProfile');

              final approvalStatus = data['approval_status'] as String?;

              // If approved → login to get tokens
              if (approvalStatus == 'approved') {
                try {
                  await loginWithPhone(phone, pinHash);
                  await AuthService.clearPendingApproval();
                  return; // authenticated
                } catch (_) {
                  // Login failed despite approved status — treat as pending
                }
              }

              // Sync local pending state with DB truth
              if (hasGuardProfile) {
                await AuthService.setPendingApproval(role: 'guard');
              }
              if (hasCustomerProfile) {
                await AuthService.setPendingApproval(role: 'customer');
              }

              _status = AuthStatus.pendingApproval;
              _role = dbRole;
              _phone = phone;
              notifyListeners();
              return;
            }
          } catch (e) {
            debugPrint('[AuthProvider] check-status error: $e');
          }

          // check-status failed (network) — fallback to local state
          if (await AuthService.isPendingApproval()) {
            _status = AuthStatus.pendingApproval;
            _role = await AuthService.getPendingRole();
            _phone = phone;
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint('[AuthProvider] checkAuth error: $e');
        // Fallback to local pending state
        if (await AuthService.isPendingApproval()) {
          _status = AuthStatus.pendingApproval;
          _role = await AuthService.getPendingRole();
          _phone = phone;
          notifyListeners();
          return;
        }
      }
    }

    // No phone or no pending state → truly unauthenticated
    if (await AuthService.isPendingApproval()) {
      await AuthService.clearPendingApproval();
    }

    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Fetch the authenticated user's profile from GET /auth/me.
  /// Returns true if profile was loaded successfully.
  Future<bool> fetchProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      debugPrint('[AuthProvider] fetchProfile response: ${response.data}');
      final data = response.data['data'];
      if (data == null) {
        debugPrint('[AuthProvider] fetchProfile: response.data["data"] is null!');
        return false;
      }
      final rawId = data['id'];
      _userId = rawId is String ? rawId : rawId?.toString();
      _fullName = data['full_name'] as String?;
      _phone = data['phone'] as String?;
      _email = data['email'] as String?;
      _approvalStatus = data['approval_status'] as String?;
      _createdAt = data['created_at'] as String?;
      _avatarUrl = data['avatar_url'] as String?;
      _companyName = data['company_name'] as String?;
      _contactPhone = data['contact_phone'] as String?;
      _gender = data['gender'] as String?;
      _dateOfBirth = data['date_of_birth'] as String?;
      _yearsOfExperience = data['years_of_experience'] as int?;
      _previousWorkplace = data['previous_workplace'] as String?;
      _customerFullName = data['customer_full_name'] as String?;
      _customerAddress = data['customer_address'] as String?;
      _customerApprovalStatus = data['customer_approval_status'] as String?;
      final role = data['role'] as String?;
      if (role != null) _role = role;
      debugPrint('[AuthProvider] profile loaded: fullName=$_fullName, phone=$_phone, role=$_role, gender=$_gender, customerApproval=$_customerApprovalStatus');
      notifyListeners();
      return true;
    } on DioException catch (e) {
      debugPrint('[AuthProvider] fetchProfile DioError: ${e.response?.statusCode} ${e.response?.data} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] fetchProfile error: $e');
      return false;
    }
  }

  /// Fetch guard document URLs from GET /auth/guards/{userId}/profile.
  Future<void> fetchGuardDocs({bool force = false}) async {
    if (_userId == null || (_docsLoaded && !force)) return;
    try {
      final response = await _apiClient.dio.get('/auth/guards/$_userId/profile');
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        _guardDocUrls = {
          'id_card': data['id_card_url'] as String?,
          'security_license': data['security_license_url'] as String?,
          'training_cert': data['training_cert_url'] as String?,
          'criminal_check': data['criminal_check_url'] as String?,
          'driver_license': data['driver_license_url'] as String?,
        };
        _guardDocExpiry = {
          'id_card': data['id_card_expiry'] as String?,
          'security_license': data['security_license_expiry'] as String?,
          'training_cert': data['training_cert_expiry'] as String?,
          'criminal_check': data['criminal_check_expiry'] as String?,
          'driver_license': data['driver_license_expiry'] as String?,
        };
        _docsLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] fetchGuardDocs error: $e');
    }
  }

  /// Update own document expiry dates.
  Future<void> updateDocExpiry(Map<String, String> expiry) async {
    await _apiClient.dio.put('/auth/guards/me/expiry', data: expiry);
    // Refresh local state
    for (final entry in expiry.entries) {
      final key = entry.key.replaceAll('_expiry', '');
      _guardDocExpiry[key] = entry.value;
    }
    notifyListeners();
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
    final response = await _apiClient.dio.post(
      '/auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );
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
    final data = <String, dynamic>{'phone_verified_token': phoneVerifiedToken};
    if (role != null) data['role'] = role;
    if (password != null) data['password'] = password;
    if (fullName != null) data['full_name'] = fullName;
    if (email != null) data['email'] = email;

    final response = await _apiClient.dio.post(
      '/auth/register/otp',
      data: data,
    );

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
      data: <String, dynamic>{'phone': phone, 'role': ?role},
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

    // DON'T set pending_role here — wait until profile is actually submitted.
    // If we set it now and user abandons the form, they'll be stuck on pending screen.
    _role = role;
    notifyListeners();

    // Return profile_token
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
    Map<String, String> documentExpiry = const {},
  }) async {
    final formData = FormData();

    if (fullName != null) formData.fields.add(MapEntry('full_name', fullName));
    if (gender != null) formData.fields.add(MapEntry('gender', gender));
    if (dateOfBirth != null) {
      formData.fields.add(MapEntry('date_of_birth', dateOfBirth));
    }
    if (yearsOfExperience != null) {
      formData.fields.add(
        MapEntry('years_of_experience', yearsOfExperience.toString()),
      );
    }
    if (previousWorkplace != null) {
      formData.fields.add(MapEntry('previous_workplace', previousWorkplace));
    }
    if (bankName != null) formData.fields.add(MapEntry('bank_name', bankName));
    if (accountNumber != null) {
      formData.fields.add(MapEntry('account_number', accountNumber));
    }
    if (accountName != null) {
      formData.fields.add(MapEntry('account_name', accountName));
    }
    for (final entry in documentExpiry.entries) {
      formData.fields.add(MapEntry(entry.key, entry.value));
    }

    for (final entry in files.entries) {
      formData.files.add(
        MapEntry(entry.key, await MultipartFile.fromFile(entry.value.path)),
      );
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
        if (contactPhone != null && contactPhone.isNotEmpty)
          'contact_phone': contactPhone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (companyName != null && companyName.isNotEmpty)
          'company_name': companyName,
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
    final response = await _apiClient.dio.post(
      '/auth/login/phone',
      data: {'phone': phone, 'password': pinHash},
    );
    final data = response.data['data'];
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final role = data['role'] as String? ?? '';

    await Future.wait([
      AuthService.storeTokens(accessToken, refreshToken),
      if (role.isNotEmpty) AuthService.storeRole(role),
      AuthService.clearPendingApproval(),
    ]);

    _role = role.isNotEmpty ? role : null;
    await fetchProfile(); // Load profile BEFORE notifying UI
    _status = AuthStatus.authenticated;
    notifyListeners();
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
    _userId = null;
    _role = null;
    _fullName = null;
    _phone = null;
    _avatarUrl = null;
    _email = null;
    _approvalStatus = null;
    _createdAt = null;
    _companyName = null;
    _contactPhone = null;
    _gender = null;
    _dateOfBirth = null;
    _yearsOfExperience = null;
    _previousWorkplace = null;
    _guardDocUrls = {};
    _docsLoaded = false;
    _customerFullName = null;
    _customerAddress = null;
    _customerApprovalStatus = null;
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
