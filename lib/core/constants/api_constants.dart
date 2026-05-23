// lib/core/constants/api_constants.dart
// W2: added coupon/processing-mode/quick-dial/scheduled/mpesa-status endpoints.
// Removed categories (D-W2-1). Renames from W1 retained.
class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://observant-smile-production-a472.up.railway.app/',
  );

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String register = '/auth/register';
  static const String verifyPhone = '/auth/verify-phone';
  static const String resetPin = '/auth/reset-pin';

  // Agent
  static const String agentProfile = '/agents/me';
  static const String updateProfile = '/agents/profile';
  static const String agentStats = '/agents/stats';

  // Wallet
  static const String walletBalance = '/wallet/balance';
  static const String walletPurchases = '/wallet/purchases';
  static const String purchaseSubscription = '/wallet/purchase-subscription';
  static const String initiateMpesa = '/wallet/mpesa/initiate'; // legacy, unused
  static const String confirmPayment = '/wallet/confirm';
  static const String processingMode = '/wallet/processing-mode'; // W2 (Q-W2-21)

  // Subscriptions
  static const String subscriptionPackages = '/subscriptions/packages';
  static const String subscriptionPlansMe = '/subscriptions/plans/me';

  // Coupons (W2 — Q-W2-19)
  static const String couponsRedeem = '/coupons/redeem';

  // Offers (W2 — OfferType enum; no categories endpoint)
  static const String offers = '/offers';

  // Transactions
  static const String transactions = '/transactions';                       // W2: POST = Quick Dial
  static const String transactionStatus = '/transactions/{id}/status';
  static const String transactionHistory = '/transactions/history';
  static const String retryTransaction = '/transactions/{id}/retry';        // legacy, unused
  static const String scheduledTransactions = '/transactions/scheduled';    // W2 (auto-renewals)
  static const String scheduleTransaction = '/transactions/schedule';       // W2

  // M-Pesa
  static const String mpesaStatus = '/mpesa/status/{checkoutRequestId}';    // W2 polling

  // USSD
  static const String ussdHealth = '/ussd/health';
  static const String ussdCodes = '/ussd/codes';
  static const String ussdAnomalies = '/ussd/anomalies';

  // Commission (kept — W5)
  static const String commissionSummary = '/commissions/summary';
  static const String commissionHistory = '/commissions/history';

  // System
  static const String systemStatus = '/system/status';
  static const String maintenance = '/system/maintenance';
}