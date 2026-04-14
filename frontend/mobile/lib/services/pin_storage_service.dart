import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinStorageService {
  static const _keyPinHash = 'pin_hash';
  static const _keyBiometric = 'biometric_enabled';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  // Cached hash for synchronous isPinSet check
  String? _cachedPinHash;

  PinStorageService(this._secureStorage, this._prefs);

  static Future<PinStorageService> init() async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    final prefs = await SharedPreferences.getInstance();
    final service = PinStorageService(secureStorage, prefs);
    // Load cached hash for synchronous access
    service._cachedPinHash = await secureStorage.read(key: _keyPinHash);
    // Reset stale biometric flag if PIN was cleared (e.g. after backup restore)
    if (service._cachedPinHash == null && service.isBiometricEnabled) {
      await prefs.setBool(_keyBiometric, false);
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

  Future<void> savePin(String pin) async {
    final hash = hashPin(pin);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    _cachedPinHash = hash;
  }

  bool validatePin(String pin) {
    if (_cachedPinHash == null) return false;
    return hashPin(pin) == _cachedPinHash;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometric, enabled);
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: _keyPinHash);
    _cachedPinHash = null;
    await _prefs.remove(_keyBiometric);
  }
}
