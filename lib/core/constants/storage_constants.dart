class StorageConstants {
  // Secure Storage Keys
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String agentId = 'agent_id';
  static const String sessionExpiry = 'session_expiry';
  static const String deviceId = 'device_id';
  static const String biometricKey = 'biometric_key';
  static const String encryptedPin = 'encrypted_pin';
  
  // Shared Preferences Keys
  static const String themeMode = 'theme_mode';
  static const String languageCode = 'language_code';
  static const String lastSyncTime = 'last_sync_time';
  static const String cachedBalance = 'cached_balance';
  static const String cachedStats = 'cached_stats';
  static const String offlineQueue = 'offline_queue';
  static const String pendingTransactions = 'pending_transactions';
  
  // Database Constants
  static const String dbName = 'bingwa_pro.db';
  static const int dbVersion = 1;
  
  // Table Names
  static const String tableTransactions = 'transactions';
  static const String tableWallet = 'wallet';
  static const String tableProducts = 'products';
  static const String tableSession = 'session';
  
  // Column Names
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colStatus = 'status';
  static const String colAmount = 'amount';
  static const String colPhone = 'phone';
}