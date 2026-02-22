class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.8:3000',
  );
  
  // Auth Endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String register = '/auth/register';
  static const String verifyPhone = '/auth/verify-phone';
  static const String resetPin = '/auth/reset-pin';
  
  // Agent Endpoints
  static const String agentProfile = '/agents/me';
  static const String updateProfile = '/agents/profile';
  static const String agentStats = '/agents/stats';
  
  // Wallet Endpoints
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String purchaseTokens = '/wallet/credit'; // Changed
  static const String initiateMpesa = '/wallet/mpesa/initiate';
  static const String confirmPayment = '/wallet/confirm';
  
  // Transaction Endpoints
  static const String airtime = '/transactions/airtime';
  static const String data = '/transactions/data';
  static const String sms = '/transactions/sms';
  static const String transactionStatus = '/transactions/{id}/status';
  static const String transactionHistory = '/transactions/history';
  static const String retryTransaction = '/transactions/{id}/retry';
  
  // USSD Endpoints
  static const String ussdHealth = '/ussd/health';
  static const String ussdCodes = '/ussd/codes';
  static const String ussdAnomalies = '/ussd/anomalies';
  
  // Product Endpoints
  static const String products = '/products';
  static const String safaricomBundles = '/products/safaricom/bundles';
  
  // Commission Endpoints
  static const String commissionSummary = '/commissions/summary';
  static const String commissionHistory = '/commissions/history';
  
  // System Endpoints
  static const String systemStatus = '/system/status';
  static const String maintenance = '/system/maintenance';
}