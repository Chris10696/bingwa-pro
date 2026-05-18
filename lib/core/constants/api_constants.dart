// lib/core/constants/api_constants.dart
// W1: URL constants updated.
//   - Renamed: walletTransactions → walletPurchases (Q9)
//   - Renamed: purchaseTokens → purchaseSubscription (Q9)
//   - Added:   offers, categories, subscriptionPackages, subscriptionPlansMe
//   - Removed: airtime, data, sms (screens deleted)
//   - Removed: products, safaricomBundles (replaced by offers module)
//   - Kept:    commissionSummary, commissionHistory (W5 cleanup task)

class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://observant-smile-production-a472.up.railway.app/',
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

  // Wallet Endpoints (W1 — renames per Q9)
  static const String walletBalance = '/wallet/balance';
  static const String walletPurchases = '/wallet/purchases';                  // renamed from /wallet/transactions
  static const String purchaseSubscription = '/wallet/purchase-subscription'; // renamed from /wallet/credit
  static const String initiateMpesa = '/wallet/mpesa/initiate';
  static const String confirmPayment = '/wallet/confirm';

  // Subscription Endpoints (W1 — new)
  static const String subscriptionPackages = '/subscriptions/packages';
  static const String subscriptionPlansMe = '/subscriptions/plans/me';

  // Offer Endpoints (W1 — new, replaces products)
  static const String offers = '/offers';
  static const String categories = '/categories';

  // Transaction Endpoints
  // NOTE: /transactions/airtime, /transactions/data, /transactions/sms removed
  // (their client screens are deleted in W1; their unified replacement
  // /offers/:id/execute ships in W2).
  static const String transactionStatus = '/transactions/{id}/status';
  static const String transactionHistory = '/transactions/history';
  static const String retryTransaction = '/transactions/{id}/retry';

  // USSD Endpoints
  static const String ussdHealth = '/ussd/health';
  static const String ussdCodes = '/ussd/codes';
  static const String ussdAnomalies = '/ussd/anomalies';

  // Commission Endpoints (kept per primer — W5 cleanup task)
  static const String commissionSummary = '/commissions/summary';
  static const String commissionHistory = '/commissions/history';

  // System Endpoints
  static const String systemStatus = '/system/status';
  static const String maintenance = '/system/maintenance';
}