import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import '../constants/storage_constants.dart';
import '../errors/exceptions.dart';
import '../utils/logger.dart';

class SecureStorageManager {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Generate a key - in production, this should be securely generated and stored
  static final _key = encrypt_lib.Key.fromLength(32);
  static final _iv = encrypt_lib.IV.fromLength(16);
  static final _encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_key));
  
  // Storage version for migration
  static const int _currentStorageVersion = 1;
  static const String _storageVersionKey = 'storage_version';

  
  // Initialize and check storage health
    // Initialize and check storage health
  static Future<void> initialize() async {
    try {
      // Check if we need to migrate or repair storage
      final versionString = await _storage.read(key: _storageVersionKey);
      
      if (versionString == null) {
        // First time initialization
        await _storage.write(key: _storageVersionKey, value: _currentStorageVersion.toString());
      } else {
        final version = int.tryParse(versionString) ?? 0;
        if (version < _currentStorageVersion) {
          await _migrateStorage(version);
        }
      }
      
      // Validate existing data
      await _validateStorage();
      
    } catch (e) {
      AppLogger.e('Storage initialization failed', e);
      // If initialization fails, clear corrupted data
      await forceClearCorruptedStorage();
    }
  }

  // Migrate from old storage versions
  static Future<void> _migrateStorage(int oldVersion) async {
    try {
      AppLogger.i('Migrating storage from version $oldVersion to $_currentStorageVersion');
      
      if (oldVersion < 1) {
        // Version 0 to 1 migration
        // Re-encrypt any existing tokens to ensure proper format
        final oldToken = await _safeRead(StorageConstants.authToken);
        if (oldToken != null && oldToken.isNotEmpty) {
          await _safeWrite(StorageConstants.authToken, oldToken);
        }
        
        final oldRefreshToken = await _safeRead(StorageConstants.refreshToken);
        if (oldRefreshToken != null && oldRefreshToken.isNotEmpty) {
          await _safeWrite(StorageConstants.refreshToken, oldRefreshToken);
        }
      }
      
      // Update version
      await _storage.write(key: _storageVersionKey, value: _currentStorageVersion.toString());
      AppLogger.i('Storage migration completed');
      
    } catch (e) {
      AppLogger.e('Storage migration failed', e);
      throw e;
    }
  }

  // Validate storage integrity
  static Future<void> _validateStorage() async {
    try {
      // Try to read each key to validate data integrity
      final keys = [
        StorageConstants.authToken,
        StorageConstants.refreshToken,
        StorageConstants.sessionExpiry,
        StorageConstants.agentId,
        StorageConstants.deviceId,
        StorageConstants.encryptedPin,
        StorageConstants.biometricKey,
      ];
      
      for (final key in keys) {
        try {
          final value = await _storage.read(key: key);
          if (value != null) {
            // Try to decrypt if it's an encrypted key
            if (key == StorageConstants.authToken || 
                key == StorageConstants.refreshToken ||
                key == StorageConstants.encryptedPin ||
                key == StorageConstants.biometricKey) {
              try {
                _encrypter.decrypt64(value, iv: _iv);
              } catch (e) {
                AppLogger.w('Corrupted encrypted data detected for key: $key');
                await _storage.delete(key: key);
              }
            }
          }
        } catch (e) {
          AppLogger.w('Corrupted data detected for key: $key');
          await _storage.delete(key: key);
        }
      }
      
    } catch (e) {
      AppLogger.e('Storage validation failed', e);
    }
  }

  // Force clear all corrupted storage (last resort)
  static Future<void> forceClearCorruptedStorage() async {
    try {
      AppLogger.w('Force clearing corrupted storage');
      await _storage.deleteAll();
      await _storage.write(key: _storageVersionKey, value: _currentStorageVersion.toString());
      AppLogger.i('Storage cleared successfully');
    } catch (e) {
      AppLogger.e('Failed to clear storage', e);
    }
  }

  // Safe read with error handling
  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      AppLogger.e('Failed to read key: $key', e);
      // Delete corrupted key
      try {
        await _storage.delete(key: key);
      } catch (deleteError) {
        AppLogger.e('Failed to delete corrupted key: $key', deleteError);
      }
      return null;
    }
  }

  // Safe write with error handling
  static Future<bool> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      AppLogger.e('Failed to write key: $key', e);
      return false;
    }
  }

  // Token Management
  static Future<void> saveAuthToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _safeWrite(StorageConstants.authToken, encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save auth token: $e');
    }
  }
  
  static Future<String?> getAuthToken() async {
    try {
      final encrypted = await _safeRead(StorageConstants.authToken);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      AppLogger.e('Failed to get auth token', e);
      // Delete corrupted token
      await _storage.delete(key: StorageConstants.authToken);
      return null;
    }
  }
  
  static Future<void> saveRefreshToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _safeWrite(StorageConstants.refreshToken, encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save refresh token: $e');
    }
  }
  
  static Future<String?> getRefreshToken() async {
    try {
      final encrypted = await _safeRead(StorageConstants.refreshToken);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      AppLogger.e('Failed to get refresh token', e);
      await _storage.delete(key: StorageConstants.refreshToken);
      return null;
    }
  }
  
  // Session Management
  static Future<void> saveSessionExpiry(DateTime expiry) async {
    await _safeWrite(
      StorageConstants.sessionExpiry,
      expiry.toIso8601String(),
    );
  }
  
  static Future<DateTime?> getSessionExpiry() async {
    final expiryString = await _safeRead(StorageConstants.sessionExpiry);
    if (expiryString == null) return null;
    
    try {
      return DateTime.parse(expiryString);
    } catch (e) {
      AppLogger.e('Failed to parse session expiry', e);
      await _storage.delete(key: StorageConstants.sessionExpiry);
      return null;
    }
  }
  
  // Device Management
  static Future<void> saveDeviceId(String deviceId) async {
    await _safeWrite(StorageConstants.deviceId, deviceId);
  }
  
  static Future<String?> getDeviceId() async {
    return await _safeRead(StorageConstants.deviceId);
  }
  
  // PIN Management
  static Future<void> saveEncryptedPin(String pin) async {
    try {
      final encrypted = _encrypter.encrypt(pin, iv: _iv);
      await _safeWrite(StorageConstants.encryptedPin, encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save PIN: $e');
    }
  }
  
  static Future<String?> getEncryptedPin() async {
    try {
      final encrypted = await _safeRead(StorageConstants.encryptedPin);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      AppLogger.e('Failed to get PIN', e);
      await _storage.delete(key: StorageConstants.encryptedPin);
      return null;
    }
  }
  
  // Agent Management
  static Future<void> saveAgentId(String agentId) async {
    await _safeWrite(StorageConstants.agentId, agentId);
  }
  
  static Future<String?> getAgentId() async {
    return await _safeRead(StorageConstants.agentId);
  }
  
  // Biometric Management
  static Future<void> saveBiometricKey(String key) async {
    try {
      final encrypted = _encrypter.encrypt(key, iv: _iv);
      await _safeWrite(StorageConstants.biometricKey, encrypted.base64);
    } catch (e) {
      throw EncryptionException('Failed to save biometric key: $e');
    }
  }
  
  static Future<String?> getBiometricKey() async {
    try {
      final encrypted = await _safeRead(StorageConstants.biometricKey);
      if (encrypted == null) return null;
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      AppLogger.e('Failed to get biometric key', e);
      await _storage.delete(key: StorageConstants.biometricKey);
      return null;
    }
  }
  
  // Check if biometric is enabled
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
    try {
      AppLogger.i('Clearing all secure storage');
      await _storage.deleteAll();
      await _storage.write(key: _storageVersionKey, value: _currentStorageVersion.toString());
      AppLogger.i('All storage cleared successfully');
    } catch (e) {
      AppLogger.e('Failed to clear all storage', e);
      // Last resort: force delete all
      try {
        await _storage.deleteAll();
      } catch (fatalError) {
        AppLogger.e('Fatal error clearing storage', fatalError);
      }
    }
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
    try {
      final token = await getAuthToken();
      if (token == null) return false;
      
      final expiry = await getSessionExpiry();
      if (expiry == null) return false;
      
      // Check if token is expired (with 5 minute buffer)
      final now = DateTime.now();
      final buffer = Duration(minutes: 5);
      
      if (now.add(buffer).isAfter(expiry)) {
        AppLogger.d('Session expired or about to expire');
        return false;
      }
      
      return true;
    } catch (e) {
      AppLogger.e('Session validation failed', e);
      return false;
    }
  }
  
  // New method to check if user is authenticated via token
  static Future<bool> isAuthenticated() async {
    return await isLoggedIn();
  }
}