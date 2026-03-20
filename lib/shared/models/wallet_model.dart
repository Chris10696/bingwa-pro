// lib/shared/models/wallet_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';
part 'wallet_model.g.dart';

// Wallet Transaction Types
enum WalletTransactionType {
  @JsonValue('PURCHASE')
  purchase,
  @JsonValue('DEDUCTION')
  deduction,
  @JsonValue('REFUND')
  refund,
  @JsonValue('COMMISSION')
  commission,
  @JsonValue('ADJUSTMENT')
  adjustment,
  @JsonValue('BONUS')
  bonus,
  @JsonValue('TRANSFER')
  transfer,
  @JsonValue('WITHDRAWAL')
  withdrawal,
}

// Wallet Transaction Status
enum WalletTransactionStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('SUCCESS')
  success,
  @JsonValue('FAILED')
  failed,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('REVERSED')
  reversed,
}

// Wallet Transaction
@freezed
abstract class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String id,
    required String agentId,
    required WalletTransactionType type,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    required WalletTransactionStatus status,
    required DateTime timestamp,
    required String reference,
    String? description,
    String? paymentMethod,
    String? paymentReference,
    String? transactionId,
    String? reversedTransactionId,
    String? initiatedBy,
    String? approvedBy,
    DateTime? approvedAt,
    String? recipientAgentId,
    String? recipientPhone,
    Map<String, dynamic>? metadata,
  }) = _WalletTransaction;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
}

// Wallet Balance - UPDATED with token fields
@freezed
abstract class WalletBalance with _$WalletBalance {
  const factory WalletBalance({
    required String agentId,
    required double availableBalance,
    required double pendingBalance,
    required double totalBalance,
    required double lockedBalance,
    required DateTime lastUpdated,
    @Default(0.0) double totalDeposits,
    @Default(0.0) double totalWithdrawals,
    @Default(0.0) double totalCommission,
    @Default(0.0) double totalBonuses,
    
    // ===== TOKEN FIELDS - ADD THESE =====
    @Default(0) int tokenBalanceInt,
    @Default(0) int lifetimeTokens,
    @Default(0) int tokensConsumed,
    // ====================================
    
  }) = _WalletBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) =>
      _$WalletBalanceFromJson(json);
}

// Token Purchase Request
@freezed
abstract class TokenPurchaseRequest with _$TokenPurchaseRequest {
  const factory TokenPurchaseRequest({
    required String agentId,
    required double amount,
    required String paymentMethod,
    String? tillNumber,
    String? paybillNumber,
    String? accountNumber,
    String? phoneNumber,
    required String deviceId,
  }) = _TokenPurchaseRequest;

  factory TokenPurchaseRequest.fromJson(Map<String, dynamic> json) =>
      _$TokenPurchaseRequestFromJson(json);
}

// Transfer Request
@freezed
abstract class TransferRequest with _$TransferRequest {
  const factory TransferRequest({
    required String fromAgentId,
    required String toAgentId,
    required double amount,
    required String description,
    required String deviceId,
    String? reference,
  }) = _TransferRequest;

  factory TransferRequest.fromJson(Map<String, dynamic> json) =>
      _$TransferRequestFromJson(json);
}

// Withdrawal Request
@freezed
abstract class WithdrawalRequest with _$WithdrawalRequest {
  const factory WithdrawalRequest({
    required String agentId,
    required double amount,
    required String phoneNumber,
    required String paymentMethod,
    required String deviceId,
    String? tillNumber,
    String? paybillNumber,
    String? accountNumber,
    String? description,
    String? reference,
  }) = _WithdrawalRequest;

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      _$WithdrawalRequestFromJson(json);
}

// M-Pesa Payment Request
@freezed
abstract class MpesaPaymentRequest with _$MpesaPaymentRequest {
  const factory MpesaPaymentRequest({
    required String phoneNumber,
    required double amount,
    required String reference,
    required String description,
    @Default('CustomerPayBillOnline') String commandId,
    String? callBackURL,
  }) = _MpesaPaymentRequest;

  factory MpesaPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$MpesaPaymentRequestFromJson(json);
}

// Payment Confirmation
@freezed
abstract class PaymentConfirmation with _$PaymentConfirmation {
  const factory PaymentConfirmation({
    required String transactionId,
    required String reference,
    required String status,
    required DateTime timestamp,
    String? mpesaReceipt,
    String? resultCode,
    String? resultDesc,
    double? amount,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
  }) = _PaymentConfirmation;

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) =>
      _$PaymentConfirmationFromJson(json);
}

// Wallet Summary
@freezed
abstract class WalletSummary with _$WalletSummary {
  const factory WalletSummary({
    required WalletBalance balance,
    required List<WalletTransaction> recentTransactions,
    @Default(0.0) double dailySpent,
    @Default(0.0) double weeklySpent,
    @Default(0.0) double monthlySpent,
    @Default(0) int transactionCountToday,
    DateTime? lastPurchaseDate,
    double? lastPurchaseAmount,
  }) = _WalletSummary;

  factory WalletSummary.fromJson(Map<String, dynamic> json) =>
      _$WalletSummaryFromJson(json);
}

// Airtime Payment Request
@freezed
abstract class AirtimePaymentRequest with _$AirtimePaymentRequest {
  const factory AirtimePaymentRequest({
    required String agentId,
    required double amount,
    required String phoneNumber,
    required String reference,
    required String deviceId,
  }) = _AirtimePaymentRequest;

  factory AirtimePaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$AirtimePaymentRequestFromJson(json);
}

// Payment Methods
@freezed
abstract class PaymentMethod with _$PaymentMethod {
  const factory PaymentMethod({
    required String id,
    required String name,
    required String type,
    required String displayName,
    required String description,
    @Default(true) bool isActive,
    double? minAmount,
    double? maxAmount,
    String? accountNumber,
    String? tillNumber,
    String? paybillNumber,
    String? instructions,
    Map<String, dynamic>? metadata,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
}