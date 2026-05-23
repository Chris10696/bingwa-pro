// lib/core/security/secure_storage_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_constants.dart';
//import '../errors/exceptions.dart';
import '../utils/logger.dart';

class SecureStorageManager {
  // flutter_secure_storage handles encryption at rest via the Android Keystore
  // (hardware-backed). We pin the cipher explicitly and enable migration so the
  // legacy RSA-encrypted values transparently move to AES-GCM on first access.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      preferencesKeyPrefix: 'bingwa_',
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Fallback SharedPreferences for when secure storage fails
  static SharedPreferences? _prefs;

  // NOTE (W2 fix): the previous build wrapped every token in a second AES layer
  // using encrypt_lib.Key.fromLength(32) / IV.fromLength(16). Those are RANDOM
  // and regenerated on every app launch, so any token saved in one session was
  // undecryptable in the next ("Invalid or corrupted pad block" → garbage token
  // → 401 storm). flutter_secure_storage already encrypts at rest with a
  // persistent keystore key, so that inner layer was redundant AND fatal to
  // session persistence. It has been removed entirely.
  
 
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
      
    } catch (e, st) {
  AppLogger.e('Storage initialization failed (continuing without clearing)', e, st);
  // Do NOT forceClearCorruptedStorage here — that nukes the user's session
  // on any transient init error. Let the real failure surface organically.
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
          await _safeRead(key); // readability check only
        } catch (e) {
          AppLogger.w('Corrupted data detected for key: $key — deleting');
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
      return await _storage.read(key: key);
    } catch (e) {
      // Includes keystore decryption failures ("corrupted pad block") from a
      // pre-migration cipher. Treat as absent and self-heal by removing it, so
      // the app cleanly routes to login rather than sending a garbage token.
      AppLogger.w('Secure read failed for key: $key — treating as absent', e);
      try {
        await _storage.delete(key: key);
      } catch (_) {/* best effort */}
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
    // Stored directly; flutter_secure_storage encrypts at rest.
    await _safeWrite(StorageConstants.authToken, token);
  }

  static Future<String?> getAuthToken() async {
    final value = await _safeRead(StorageConstants.authToken);
    if (value == null || value.isEmpty) return null;
    return value;
  }
  
  static Future<void> saveRefreshToken(String token) async {
    await _safeWrite(StorageConstants.refreshToken, token);
  }

  static Future<String?> getRefreshToken() async {
    final value = await _safeRead(StorageConstants.refreshToken);
    if (value == null || value.isEmpty) return null;
    return value;
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
    await _safeWrite(StorageConstants.encryptedPin, pin);
  }

  static Future<String?> getEncryptedPin() async {
    final value = await _safeRead(StorageConstants.encryptedPin);
    if (value == null || value.isEmpty) return null;
    return value;
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
    await _safeWrite(StorageConstants.biometricKey, key);
  }

  static Future<String?> getBiometricKey() async {
    final value = await _safeRead(StorageConstants.biometricKey);
    if (value == null || value.isEmpty) return null;
    return value;
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