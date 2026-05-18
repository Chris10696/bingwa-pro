// lib/shared/models/wallet_model.dart
// W1: dramatically restructured.
//   - WalletBalance reshaped to match new /wallet/balance composite payload.
//   - WalletTransaction renamed to SubscriptionPurchase (Q5 lock).
//   - WalletTransactionType/Status enums replaced by SubscriptionPurchaseStatus
//     (purchase-only audit per primer locked decision 3).
//   - Dropped: TokenPurchaseRequest, TransferRequest, WithdrawalRequest,
//     MpesaPaymentRequest, WalletSummary, AirtimePaymentRequest, PaymentMethod
//     (their endpoints/methods are deleted in W1).
//   - Added: SubscriptionPurchaseRequest for /wallet/purchase-subscription.
//   - Kept: PaymentConfirmation (confirmPayment flow retained).
import 'package:freezed_annotation/freezed_annotation.dart';
import 'subscription_plan_model.dart';

part 'wallet_model.freezed.dart';
part 'wallet_model.g.dart';

// Status for SubscriptionPurchase audit rows (matches backend enum exactly).
enum SubscriptionPurchaseStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('FAILED')
  failed,
  @JsonValue('REVERSED')
  reversed,
}

// Processing mode for the wallet's processing state.
enum ProcessingMode {
  @JsonValue('express')
  express,
  @JsonValue('advanced')
  advanced,
}

// SubscriptionPurchase: purchase-only audit row (Q5 rename from
// WalletTransaction). Matches backend src/subscriptions/entities/subscription-purchase.entity.ts.
@freezed
abstract class SubscriptionPurchase with _$SubscriptionPurchase {
  const factory SubscriptionPurchase({
    required String id,
    required String agentId,
    required String packageId,
    required int amountPaid,
    required String paymentReference,
    required SubscriptionPurchaseStatus status,
    required DateTime createdAt,
    Map<String, dynamic>? metadata,
  }) = _SubscriptionPurchase;

  factory SubscriptionPurchase.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPurchaseFromJson(json);
}

// Composite wallet-state payload returned by GET /wallet/balance.
// Shape per primer:
//   { hasUsableTokens, plans, wallet: {processingMode, isProcessing,
//     lifetimeTokensPurchased, lifetimeTokensConsumed} }
//
// The nested `wallet` object is represented by WalletProcessingState below.
@freezed
abstract class WalletBalance with _$WalletBalance {
  const factory WalletBalance({
    @Default(false) bool hasUsableTokens,
    @Default([]) List<SubscriptionPlan> plans,
    WalletProcessingState? wallet,
  }) = _WalletBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    // Manual conversion: plans use the plain-Dart SubscriptionPlan model
    // (no fromJson freezed bridge), so the generated _$ factory can't deserialize
    // the list directly. Hand-roll the read.
    final plansRaw = json['plans'] as List<dynamic>? ?? const [];
    return WalletBalance(
      hasUsableTokens: json['hasUsableTokens'] as bool? ?? false,
      plans: plansRaw
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      wallet: json['wallet'] == null
          ? null
          : WalletProcessingState.fromJson(
              json['wallet'] as Map<String, dynamic>),
    );
  }
}

// Inner wallet processing state. Matches the simplified Wallet entity fields
// exposed by /wallet/balance.
@freezed
abstract class WalletProcessingState with _$WalletProcessingState {
  const factory WalletProcessingState({
    @Default(ProcessingMode.express) ProcessingMode processingMode,
    @Default(false) bool isProcessing,
    @Default(0) int lifetimeTokensPurchased,
    @Default(0) int lifetimeTokensConsumed,
  }) = _WalletProcessingState;

  factory WalletProcessingState.fromJson(Map<String, dynamic> json) =>
      _$WalletProcessingStateFromJson(json);
}

// Request body for POST /wallet/purchase-subscription.
// Phone is optional; backend uses agent's registered number if omitted (Q8).
@freezed
abstract class SubscriptionPurchaseRequest with _$SubscriptionPurchaseRequest {
  const factory SubscriptionPurchaseRequest({
    required String packageId,
    String? phoneNumber,
  }) = _SubscriptionPurchaseRequest;

  factory SubscriptionPurchaseRequest.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPurchaseRequestFromJson(json);
}

// Payment confirmation response (kept; used by confirmPayment flow).
@freezed
abstract class PaymentConfirmation with _$PaymentConfirmation {
  const factory PaymentConfirmation({
    @Default('') String transactionId,
    @Default('') String reference,
    @Default('PENDING') String status,
    DateTime? timestamp,
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