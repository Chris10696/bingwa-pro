import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import '../constants/storage_constants.dart';
import '../errors/exceptions.dart';

class SecureStorageManager {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Generate a key - in production, this should be securely generated and stored
  static final _key = encrypt_lib.Key.fromLength(32);
  static final _iv = encrypt_lib.IV.fromLength(16);
  static final _encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_key));
  
  // Token Management
  static Future<void> saveAuthToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _storage.write(key: StorageConstants.authToken, value: encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save auth token: $e');
    }
  }
  
  static Future<String?> getAuthToken() async {
    try {
      final encrypted = await _storage.read(key: StorageConstants.authToken);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      throw EncryptionException('Failed to get auth token: $e');
    }
  }
  
  static Future<void> saveRefreshToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _storage.write(key: StorageConstants.refreshToken, value: encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save refresh token: $e');
    }
  }
  
  static Future<String?> getRefreshToken() async {
    try {
      final encrypted = await _storage.read(key: StorageConstants.refreshToken);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      throw EncryptionException('Failed to get refresh token: $e');
    }
  }
  
  // Session Management
  static Future<void> saveSessionExpiry(DateTime expiry) async {
    await _storage.write(
      key: StorageConstants.sessionExpiry,
      value: expiry.toIso8601String(),
    );
  }
  
  static Future<DateTime?> getSessionExpiry() async {
    final expiryString = await _storage.read(key: StorageConstants.sessionExpiry);
    return expiryString != null ? DateTime.parse(expiryString) : null;
  }
  
  // Device Management
  static Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: StorageConstants.deviceId, value: deviceId);
  }
  
  static Future<String?> getDeviceId() async {
    return await _storage.read(key: StorageConstants.deviceId);
  }
  
  // PIN Management
  static Future<void> saveEncryptedPin(String pin) async {
    try {
      final encrypted = _encrypter.encrypt(pin, iv: _iv);
      await _storage.write(key: StorageConstants.encryptedPin, value: encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save PIN: $e');
    }
  }
  
  static Future<String?> getEncryptedPin() async {
    try {
      final encrypted = await _storage.read(key: StorageConstants.encryptedPin);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      throw EncryptionException('Failed to get PIN: $e');
    }
  }
  
  // Agent Management
  static Future<void> saveAgentId(String agentId) async {
    await _storage.write(key: StorageConstants.agentId, value: agentId);
  }
  
  static Future<String?> getAgentId() async {
    return await _storage.read(key: StorageConstants.agentId);
  }
  
  // Biometric Management
  static Future<void> saveBiometricKey(String key) async {
    try {
      final encrypted = _encrypter.encrypt(key, iv: _iv);
      await _storage.write(key: StorageConstants.biometricKey, value: encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save biometric key: $e');
    }
  }
  
  static Future<String?> getBiometricKey() async {
    try {
      final encrypted = await _storage.read(key: StorageConstants.biometricKey);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      throw EncryptionException('Failed to get biometric key: $e');
    }
  }
  
  // NEW METHOD: Check if biometric is enabled
  static Future<bool> hasBiometricEnabled() async {
    try {
      final biometricKey = await getBiometricKey();
      return biometricKey != null && biometricKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Alternative name for compatibility
  static Future<bool> getBiometricEnabled() async {
    return await hasBiometricEnabled();
  }
  
  // Clear all storage (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
  
  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    final expiry = await getSessionExpiry();
    
    if (token == null || expiry == null) return false;
    
    final now = DateTime.now();
    return now.isBefore(expiry);
  }
  
  // Check session validity
  static Future<bool> isSessionValid() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return false;
    
    final now = DateTime.now();
    final isValid = now.isBefore(expiry);
    
    if (!isValid) {
      await clearAll();
    }
    
    return isValid;
  }
}