// lib/core/security/secure_storage_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import '../constants/storage_constants.dart';
//import '../errors/exceptions.dart';
import '../utils/logger.dart';

class SecureStorageManager {
  // Configure Android options to prevent the -16 error
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      preferencesKeyPrefix: 'bingwa_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  // Fallback SharedPreferences for when secure storage fails
  static SharedPreferences? _prefs;
  
  // Generate a key - in production, this should be securely generated and stored
  static final _key = encrypt_lib.Key.fromLength(32);
  static final _iv = encrypt_lib.IV.fromLength(16);
  static final _encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_key));
  
  // Storage version for migration
  static const int _currentStorageVersion = 1;
  static const String _storageVersionKey = 'storage_version';
  
  // Biometric preference key
  static const String _keyBiometricEnabled = 'biometric_enabled';
  
  // Initialize SharedPreferences fallback
  static Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Initialize and check storage health
  static Future<void> initialize() async {
    try {
      await _initPrefs();
      
      // Check if we need to migrate or repair storage
      final versionString = await _safeRead(_storageVersionKey);
      
      if (versionString == null) {
        // First time initialization
        await _safeWrite(_storageVersionKey, _currentStorageVersion.toString());
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
      await _safeWrite(_storageVersionKey, _currentStorageVersion.toString());
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
        _keyBiometricEnabled,
      ];
      
      for (final key in keys) {
        try {
          final value = await _safeRead(key);
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
                await _delete(key);
              }
            }
          }
        } catch (e) {
          AppLogger.w('Corrupted data detected for key: $key');
          await _delete(key);
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
      if (_prefs != null) {
        await _prefs!.clear();
      }
      await _safeWrite(_storageVersionKey, _currentStorageVersion.toString());
      AppLogger.i('Storage cleared successfully');
    } catch (e) {
      AppLogger.e('Failed to clear storage', e);
    }
  }

  // Safe read with error handling - tries secure storage first, falls back to SharedPreferences
  static Future<String?> _safeRead(String key) async {
    try {
      // Try secure storage first
      return await _storage.read(key: key);
    } catch (e) {
      // If secure storage fails, try SharedPreferences
      AppLogger.w('Secure storage read failed for key: $key, trying SharedPreferences', e);
      try {
        await _initPrefs();
        return _prefs?.getString(key);
      } catch (fallbackError) {
        AppLogger.e('Fallback read also failed for key: $key', fallbackError);
        return null;
      }
    }
  }

  // Safe write with error handling - tries secure storage first, falls back to SharedPreferences
  static Future<bool> _safeWrite(String key, String value) async {
    try {
      // Try secure storage first
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      // If secure storage fails, try SharedPreferences
      AppLogger.w('Secure storage write failed for key: $key, trying SharedPreferences', e);
      try {
        await _initPrefs();
        await _prefs?.setString(key, value);
        return true;
      } catch (fallbackError) {
        AppLogger.e('Fallback write also failed for key: $key', fallbackError);
        return false;
      }
    }
  }
  
  // Safe delete
  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
      if (_prefs != null) {
        await _prefs!.remove(key);
      }
    } catch (e) {
      AppLogger.w('Failed to delete key: $key', e);
    }
  }

  // Token Management
  static Future<void> saveAuthToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _safeWrite(StorageConstants.authToken, encrypted.base64);
    } catch (e) {
      // If encryption fails, save plain text (not recommended but better than nothing)
      AppLogger.w('Encryption failed, saving auth token in plain text', e);
      await _safeWrite(StorageConstants.authToken, token);
    }
  }
  
  static Future<String?> getAuthToken() async {
    try {
      final encrypted = await _safeRead(StorageConstants.authToken);
      if (encrypted == null) return null;
      
      // Try to decrypt
      try {
        return _encrypter.decrypt64(encrypted, iv: _iv);
      } catch (e) {
        // If decryption fails, it might be plain text from fallback
        AppLogger.w('Decryption failed, returning raw value', e);
        return encrypted;
      }
    } catch (e) {
      AppLogger.e('Failed to get auth token', e);
      return null;
    }
  }
  
  static Future<void> saveRefreshToken(String token) async {
    try {
      final encrypted = _encrypter.encrypt(token, iv: _iv);
      await _safeWrite(StorageConstants.refreshToken, encrypted.base64);
    } catch (e) {
      AppLogger.w('Encryption failed, saving refresh token in plain text', e);
      await _safeWrite(StorageConstants.refreshToken, token);
    }
  }
  
  static Future<String?> getRefreshToken() async {
    try {
      final encrypted = await _safeRead(StorageConstants.refreshToken);
      if (encrypted == null) return null;
      
      try {
        return _encrypter.decrypt64(encrypted, iv: _iv);
      } catch (e) {
        return encrypted;
      }
    } catch (e) {
      AppLogger.e('Failed to get refresh token', e);
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
      await _delete(StorageConstants.sessionExpiry);
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
      AppLogger.w('Encryption failed, saving PIN in plain text', e);
      await _safeWrite(StorageConstants.encryptedPin, pin);
    }
  }
  
  static Future<String?> getEncryptedPin() async {
    try {
      final encrypted = await _safeRead(StorageConstants.encryptedPin);
      if (encrypted == null) return null;
      
      try {
        return _encrypter.decrypt64(encrypted, iv: _iv);
      } catch (e) {
        return encrypted;
      }
    } catch (e) {
      AppLogger.e('Failed to get PIN', e);
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
      AppLogger.w('Encryption failed, saving biometric key in plain text', e);
      await _safeWrite(StorageConstants.biometricKey, key);
    }
  }
  
  static Future<String?> getBiometricKey() async {
    try {
      final encrypted = await _safeRead(StorageConstants.biometricKey);
      if (encrypted == null) return null;
      
      try {
        return _encrypter.decrypt64(encrypted, iv: _iv);
      } catch (e) {
        return encrypted;
      }
    } catch (e) {
      AppLogger.e('Failed to get biometric key', e);
      return null;
    }
  }
  
  // Check if biometric is enabled via key existence
  static Future<bool> hasBiometricEnabled() async {
    try {
      final biometricKey = await getBiometricKey();
      return biometricKey != null && biometricKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Biometric preference methods (using separate key)
  static Future<bool> getBiometricEnabled([bool defaultValue = false]) async {
    try {
      final value = await _safeRead(_keyBiometricEnabled);
      if (value == null) return defaultValue;
      return value == 'true';
    } catch (e) {
      AppLogger.e('Failed to get biometric enabled preference', e);
      return defaultValue;
    }
  }
  
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _safeWrite(_keyBiometricEnabled, enabled.toString());
    AppLogger.d('Biometric enabled preference set to: $enabled');
  }
  
  // Clear all storage (logout)
  static Future<void> clearAll() async {
    try {
      AppLogger.i('Clearing all secure storage');
      await _storage.deleteAll();
      await _initPrefs();
      await _prefs?.clear();
      await _safeWrite(_storageVersionKey, _currentStorageVersion.toString());
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
  
  // Check if user is authenticated via token
  static Future<bool> isAuthenticated() async {
    return await isLoggedIn();
  }
}