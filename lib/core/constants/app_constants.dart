class AppConstants {
  // App Info
  static const String appName = 'Bingwa Pro';
  static const String appVersion = '1.0.0';
  
  // Session Management
  static const int sessionTimeoutMinutes = 15;
  static const int refreshTokenThresholdMinutes = 5;
  
  // Security
  static const int maxLoginAttempts = 5;
  static const int loginLockoutMinutes = 15;
  
  // Transaction Limits
  static const double minTransactionAmount = 10.0;
  static const double maxTransactionAmount = 10000.0;
  static const double minTokenPurchase = 100.0;
  
  // Validation
  static const String safaricomRegex = r'^(07|01)[0-9]{8}$';
  static const String kenyaPhoneRegex = r'^(\+254|0)[17][0-9]{8}$';
  
  // Storage Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyBiometricEnabled = 'biometric_enabled';
  
  // API Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Retry Configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Cache Configuration
  static const Duration cacheDuration = Duration(minutes: 5);
  
  // Notification
  static const int notificationId = 1001;
  static const String notificationChannelId = 'bingwa_pro_transactions';
  static const String notificationChannelName = 'Transaction Updates';
}