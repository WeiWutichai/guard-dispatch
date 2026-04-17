import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [PinStorageService.validatePin] call.
///
/// Sealed type — exhaustively switch on the four subclasses to handle
/// every PIN entry outcome.
sealed class PinResult {
  const PinResult();
}

/// PIN matched the stored hash. Failure counter has been reset.
final class PinValid extends PinResult {
  const PinValid();
}

/// PIN did not match. Counter incremented but neither lockout nor wipe
/// thresholds reached.
final class PinInvalid extends PinResult {
  /// Attempts remaining before the wipe threshold (10 - currentCount).
  ///
  /// When the stored hash is missing (e.g. after a wipe) every attempt
  /// reports the full quota — the counter is not advanced because there
  /// is nothing to brute-force.
  final int remainingBeforeWipe;
  const PinInvalid({required this.remainingBeforeWipe});
}

/// Lockout window is active. The caller should refuse to consume further
/// PIN attempts until [remaining] elapses.
final class PinLockedOut extends PinResult {
  /// Time left until the lockout window expires.
  final Duration remaining;

  /// Cumulative number of failed attempts that triggered the lockout.
  final int totalAttempts;
  const PinLockedOut({required this.remaining, required this.totalAttempts});
}

/// PIN hash and biometric flag have been wiped from secure storage after
/// reaching the wipe threshold. The phone number is intentionally
/// preserved — UI is responsible for token / auth cleanup.
final class PinWiped extends PinResult {
  const PinWiped();
}

/// Local PIN storage with rate limiting and self-wipe protection.
///
/// **Security model:**
/// - PIN stored as SHA-256 hash in [FlutterSecureStorage] (Keychain / EncryptedSharedPreferences).
/// - 5 wrong attempts → 60-second lockout window.
/// - 10 wrong attempts (cumulative) → wipe `pin_hash`, `biometric_enabled`,
///   `failed_attempts`, `lock_until`. Stored phone is **not** touched —
///   the UI handler is responsible for tearing down auth tokens.
/// - Failed-attempt counter and lockout deadline persist in
///   [FlutterSecureStorage] so they survive app restarts.
/// - Concurrent [validatePin] calls are serialized via an in-flight
///   future lock — keeps the counter consistent against accidental
///   double-taps and parallel awaits.
///
/// **WARNING — clock rollback:**
/// Lockout uses wall-clock time ([DateTime.now]). An attacker with
/// physical access can rewind the device clock to skip the 60s window.
/// The wipe at attempt 10 is still effective because the counter itself
/// is monotonic. For higher security, swap [_now] for a monotonic clock
/// exposed through a platform channel.
class PinStorageService {
  static const _keyPinHash = 'pin_hash';
  static const _keyBiometric = 'biometric_enabled';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockUntil = 'pin_lock_until_ms';

  static const _lockoutThreshold = 5;
  static const _wipeThreshold = 10;
  static const _lockoutDuration = Duration(seconds: 60);

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  /// Injectable wall-clock — overridden in tests to drive lockout windows
  /// deterministically.
  final DateTime Function() _now;

  /// Cached hash for synchronous [isPinSet] / [getStoredPinHash] checks.
  String? _cachedPinHash;

  /// Serializes overlapping [validatePin] calls so concurrent awaits
  /// don't double-increment the counter or race the cached hash.
  Future<PinResult>? _validateInFlight;

  PinStorageService(
    this._secureStorage,
    this._prefs, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Bootstrap the singleton during app startup.
  ///
  /// Performs backup-restore defense: if the PIN hash is gone but the
  /// biometric flag or attempt counter still linger, clear them — they'd
  /// otherwise lock out a user who reinstalled fresh.
  static Future<PinStorageService> init({DateTime Function()? now}) async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    final prefs = await SharedPreferences.getInstance();
    final service = PinStorageService(secureStorage, prefs, now: now);
    // Load cached hash for synchronous access
    service._cachedPinHash = await secureStorage.read(key: _keyPinHash);
    // Reset stale state if PIN was cleared (e.g. after backup restore).
    if (service._cachedPinHash == null) {
      if (service.isBiometricEnabled) {
        await prefs.setBool(_keyBiometric, false);
      }
      // Stale counter / lockout would prevent a fresh PIN setup from working.
      await secureStorage.delete(key: _keyFailedAttempts);
      await secureStorage.delete(key: _keyLockUntil);
    }
    return service;
  }

  bool get isPinSet => _cachedPinHash != null;

  /// Retrieve the stored SHA-256 PIN hash (for use as login password).
  String? getStoredPinHash() => _cachedPinHash;

  bool get isBiometricEnabled => _prefs.getBool(_keyBiometric) ?? false;

  /// Compute SHA-256 hash of a PIN. Public so registration can use it as password.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Persist a freshly-chosen PIN and reset all rate-limiting state.
  ///
  /// "New PIN means fresh chances" — important after the wipe → re-OTP
  /// flow lets the user pick a brand-new PIN.
  Future<void> savePin(String pin) async {
    final hash = hashPin(pin);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    _cachedPinHash = hash;
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockUntil);
  }

  /// Validate a user-entered PIN and return one of the four [PinResult] types.
  ///
  /// Concurrent calls are serialized — the second caller awaits the first
  /// and then runs its own check, so two simultaneous wrong PINs increment
  /// the counter by exactly two.
  Future<PinResult> validatePin(String pin) async {
    // Serialize overlapping calls. Each validation runs end-to-end before
    // the next one starts.
    while (_validateInFlight != null) {
      try {
        await _validateInFlight;
      } catch (_) {
        // Swallow — the previous caller will see its own error; we just
        // need to wait for the slot to free up.
      }
    }
    final completer = Completer<PinResult>();
    _validateInFlight = completer.future;
    try {
      final result = await _runValidate(pin);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _validateInFlight = null;
    }
  }

  Future<PinResult> _runValidate(String pin) async {
    // 1. Check active lockout window first — never charge an attempt
    //    against the user while locked out.
    final activeLock = await getCurrentLockoutState();
    if (activeLock != null) {
      return activeLock;
    }

    // 2. No PIN to compare against (post-wipe). Report a "fresh" invalid
    //    result without incrementing — there is nothing to brute-force.
    if (_cachedPinHash == null) {
      return const PinInvalid(remainingBeforeWipe: _wipeThreshold);
    }

    // 3. Match path — clear counters and return success.
    if (hashPin(pin) == _cachedPinHash) {
      await _secureStorage.delete(key: _keyFailedAttempts);
      await _secureStorage.delete(key: _keyLockUntil);
      return const PinValid();
    }

    // 4. Mismatch path — bump counter, decide outcome.
    final currentCount = await getFailedAttemptCount();
    final newCount = currentCount + 1;
    await _secureStorage.write(
      key: _keyFailedAttempts,
      value: newCount.toString(),
    );

    if (newCount >= _wipeThreshold) {
      await _secureStorage.delete(key: _keyPinHash);
      await _secureStorage.delete(key: _keyFailedAttempts);
      await _secureStorage.delete(key: _keyLockUntil);
      _cachedPinHash = null;
      await _prefs.setBool(_keyBiometric, false);
      return const PinWiped();
    }

    if (newCount >= _lockoutThreshold) {
      final lockUntil = _now().add(_lockoutDuration);
      await _secureStorage.write(
        key: _keyLockUntil,
        value: lockUntil.millisecondsSinceEpoch.toString(),
      );
      return PinLockedOut(
        remaining: _lockoutDuration,
        totalAttempts: newCount,
      );
    }

    return PinInvalid(remainingBeforeWipe: _wipeThreshold - newCount);
  }

  /// Inspect the current lockout state without consuming an attempt.
  ///
  /// Returns `null` when the user is free to enter a PIN, or a
  /// [PinLockedOut] describing how much of the 60s window remains.
  Future<PinLockedOut?> getCurrentLockoutState() async {
    final raw = await _secureStorage.read(key: _keyLockUntil);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    final lockUntil = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = _now();
    if (now.isBefore(lockUntil)) {
      final totalAttempts = await getFailedAttemptCount();
      return PinLockedOut(
        remaining: lockUntil.difference(now),
        totalAttempts: totalAttempts,
      );
    }
    return null;
  }

  /// Read the persistent failed-attempt counter (0 when never set).
  Future<int> getFailedAttemptCount() async {
    final raw = await _secureStorage.read(key: _keyFailedAttempts);
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometric, enabled);
  }

  /// Wipe every PIN-related key, including the rate-limiting state.
  /// Phone number and other unrelated prefs are left alone.
  Future<void> clearAll() async {
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockUntil);
    _cachedPinHash = null;
    await _prefs.remove(_keyBiometric);
  }
}
