import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'auth_service.dart';

/// Centralized API client using Dio with JWT auth interceptor.
///
/// Reads the API base URL from the `API_URL` build-time env var
/// (passed via `--dart-define=API_URL=...`). Falls back to
/// platform-appropriate loopback: iOS → localhost, Android → 10.0.2.2.
///
/// Automatically attaches Bearer token from FlutterSecureStorage
/// and handles 401 responses with token refresh.
class ApiClient {
  static const _envBaseUrl = String.fromEnvironment('API_URL');

  static String get _defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return Platform.isIOS ? 'http://localhost:80' : 'http://10.0.2.2:80';
  }

  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? _defaultBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(_AuthInterceptor(dio));
  }
}

/// Interceptor that:
/// 1. Adds Bearer token from FlutterSecureStorage to every request.
/// 2. Proactively refreshes the token if it expires within 2 minutes.
/// 3. On 401 response, attempts to refresh the token and retry (fallback).
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isProactiveRefreshing = false;
  bool _isReactiveRefreshing = false;

  /// Buffer time before expiry to trigger proactive refresh (2 minutes).
  static const _refreshBuffer = Duration(minutes: 2);

  _AuthInterceptor(this._dio);

  /// Decode JWT payload without verification (just to read `exp`).
  static int? _getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64 decode the payload (part[1])
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['exp'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Check if token expires within [_refreshBuffer].
  static bool _isTokenExpiringSoon(String token) {
    final exp = _getTokenExpiry(token);
    if (exp == null) return false;
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expiryTime.subtract(_refreshBuffer));
  }

  /// Proactively refresh the access token. Returns the new token or null.
  Future<String?> _proactiveRefresh() async {
    if (_isProactiveRefreshing) return null;
    _isProactiveRefreshing = true;
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null) return null;

      final refreshDio = Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 10),
      ));

      final response = await refreshDio.post(
        '/auth/refresh/mobile',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final newAccessToken = data['access_token'] as String;
        final newRefreshToken = data['refresh_token'] as String;
        await AuthService.storeTokens(newAccessToken, newRefreshToken);
        return newAccessToken;
      }
    } catch (_) {
      // Proactive refresh failed — don't clear tokens, the 401 fallback
      // will handle it if the token is truly expired.
    } finally {
      _isProactiveRefreshing = false;
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for public endpoints and profile-token endpoints
    // (profile/guard and profile/customer use their own Bearer profile_token).
    //
    // Note: /auth/profile/role is intentionally NOT in this list — its
    // backend handler does optional auth: if a Bearer access_token is
    // present, it skips the phone_verified_token requirement. This lets
    // approved guards add a customer profile without re-doing OTP.
    // Unauthenticated callers (during 3-step registration) have no stored
    // access token, so the `if (token != null)` check below skips the
    // header for them and they fall through to the body's phone_verified_token.
    final publicPaths = ['/auth/login', '/auth/login/phone', '/auth/login/mobile', '/auth/check-status', '/auth/register', '/auth/otp/request', '/auth/otp/verify', '/auth/register/otp', '/auth/profile/reissue', '/auth/profile/guard', '/auth/profile/customer', '/auth/refresh/mobile'];
    final isPublic = publicPaths.any((p) => options.path.contains(p));

    if (!isPublic) {
      var token = await AuthService.getAccessToken();

      // Proactive refresh: if token expires within 2 minutes, refresh now
      // so the request never sees a 401.
      if (token != null && _isTokenExpiringSoon(token)) {
        final newToken = await _proactiveRefresh();
        if (newToken != null) {
          token = newToken;
        }
        // If proactive refresh fails, send the old token anyway —
        // it might still be valid for a few more seconds, and the
        // onError fallback will catch a real 401.
      }

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Fallback: if the request still got 401 (proactive refresh missed or
    // failed), attempt one more refresh + retry.
    if (err.response?.statusCode == 401 && !_isReactiveRefreshing) {
      _isReactiveRefreshing = true;

      try {
        final refreshToken = await AuthService.getRefreshToken();
        if (refreshToken == null) {
          return handler.next(err);
        }

        final refreshDio = Dio(BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 10),
        ));

        final response = await refreshDio.post(
          '/auth/refresh/mobile',
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200) {
          final data = response.data['data'];
          final newAccessToken = data['access_token'] as String;
          final newRefreshToken = data['refresh_token'] as String;
          await AuthService.storeTokens(newAccessToken, newRefreshToken);

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } on DioException catch (refreshErr) {
        final statusCode = refreshErr.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          await AuthService.clearTokens();
        }
      } catch (_) {
        // Non-Dio error (parsing, etc.) — don't clear tokens
      } finally {
        _isReactiveRefreshing = false;
      }
    }

    handler.next(err);
  }
}
