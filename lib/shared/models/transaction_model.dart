// lib/shared/models/transaction_model.dart
// W1 edits:
//   - TransactionType enum: drop airtime/bundle; rename token_purchase → subscription_purchase
//   - Field renames on all classes: productId → offerId, productName → offerName
//   - Drop bundleSize everywhere
//   - Add subscriptionPlanId to TransactionDetails and Transaction (Q5 lock)
//   - Drop embedded ProductBundle class (moved to offer_model.dart as Offer)
//   - Update TransactionResponseExtension to not sniff product names (was already broken)
import 'package:freezed_annotation/freezed_annotation.dart';
part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

// Transaction Types per primer locked list (DATA, MINUTES, SMS,
// SUBSCRIPTION_PURCHASE, COMMISSION). AIRTIME and BUNDLE dropped.
enum TransactionType {
  @JsonValue('data')
  data,
  @JsonValue('minutes')
  minutes,
  @JsonValue('sms')
  sms,
  @JsonValue('subscription_purchase')
  subscriptionPurchase,
  @JsonValue('commission')
  commission,
}

// Transaction Status — unchanged.
enum TransactionStatus {
  @JsonValue('initiated')
  initiated,
  @JsonValue('validated')
  validated,
  @JsonValue('executing')
  executing,
  @JsonValue('success')
  success,
  @JsonValue('failed')
  failed,
  @JsonValue('aborted')
  aborted,
  @JsonValue('pending')
  pending,
  @JsonValue('refunded')
  refunded,
  @JsonValue('disputed')
  disputed,
}

// USSD Status — unchanged.
enum UssdStatus {
  @JsonValue('green')
  green,
  @JsonValue('yellow')
  yellow,
  @JsonValue('red')
  red,
}

// Transaction Request. Field renames: productId→offerId, productName→offerName.
// bundleSize dropped. validityDays dropped (offer's validityLabel covers it).
@freezed
abstract class TransactionRequest with _$TransactionRequest {
  const factory TransactionRequest({
    required String agentId,
    required TransactionType type,
    required String customerPhone,
    required double amount,
    required String offerId,
    String? offerName,
    String? ussdCode,
    required String deviceId,
    String? customerName,
    String? customerEmail,
    Map<String, dynamic>? metadata,
  }) = _TransactionRequest;
  factory TransactionRequest.fromJson(Map<String, dynamic> json) =>
      _$TransactionRequestFromJson(json);
}

// Transaction Response. productName renamed → offerName. tokenDeduction kept
// (already nullable use, retained for backwards client compat in W1).
@freezed
abstract class TransactionResponse with _$TransactionResponse {
  const factory TransactionResponse({
    required String transactionId,
    required String reference,
    required TransactionStatus status,
    required DateTime timestamp,
    required double amount,
    @Default(0.0) double tokenDeduction,
    @Default(0.0) double commission,
    String? ussdResponse,
    String? safaricomReference,
    String? errorMessage,
    String? customerPhone,
    String? offerName,
    double? balanceAfter,
    Map<String, dynamic>? metadata,
  }) = _TransactionResponse;
  factory TransactionResponse.fromJson(Map<String, dynamic> json) =>
      _$TransactionResponseFromJson(json);
}

// Transaction Details. Field renames: productId/productName → offerId/offerName.
// Added subscriptionPlanId (Q5 lock). Dropped bundleSize.
@freezed
abstract class TransactionDetails with _$TransactionDetails {
  const factory TransactionDetails({
    required String id,
    required String agentId,
    required TransactionType type,
    required String customerPhone,
    required double amount,
    required double tokenAmount,
    required double commission,
    required TransactionStatus status,
    required DateTime createdAt,
    DateTime? completedAt,
    String? offerId,
    String? offerName,
    String? subscriptionPlanId,
    String? ussdCode,
    String? ussdResponse,
    String? safaricomReference,
    String? errorCode,
    String? errorMessage,
    String? initiatedBy,
    String? deviceId,
    String? ipAddress,
    double? balanceBefore,
    double? balanceAfter,
    bool? isAutoRetry,
    int? retryCount,
    String? parentTransactionId,
    Map<String, dynamic>? auditLogs,
    required String reference,
  }) = _TransactionDetails;
  factory TransactionDetails.fromJson(Map<String, dynamic> json) =>
      _$TransactionDetailsFromJson(json);
}

// Simplified Transaction Model for UI. productName renamed → offerName.
// bundleSize dropped. Added subscriptionPlanId (Q5 lock).
@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required TransactionType type,
    required double amount,
    required String recipientPhone,
    required TransactionStatus status,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? referenceId,
    String? description,
    String? note,
    double? commission,
    String? agentId,
    String? offerName,
    String? subscriptionPlanId,
    double? balanceAfter,
  }) = _Transaction;
  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

// Transaction Filter — unchanged.
@freezed
abstract class TransactionFilter with _$TransactionFilter {
  const factory TransactionFilter({
    DateTime? startDate,
    DateTime? endDate,
    List<TransactionType>? types,
    List<TransactionStatus>? statuses,
    String? customerPhone,
    double? minAmount,
    double? maxAmount,
    String? reference,
    @Default(1) int page,
    @Default(20) int pageSize,
    @Default('createdAt') String sortBy,
    @Default(false) bool sortDesc,
  }) = _TransactionFilter;
  factory TransactionFilter.fromJson(Map<String, dynamic> json) =>
      _$TransactionFilterFromJson(json);
}

// Transaction List Response — unchanged structurally.
@freezed
abstract class TransactionListResponse with _$TransactionListResponse {
  const factory TransactionListResponse({
    @Default([]) List<TransactionDetails> transactions,
    @Default(0) int totalCount,
    @Default(1) int page,
    @Default(20) int pageSize,
    @Default(false) bool hasNextPage,
    @Default(0.0) double totalRevenue,
    @Default(0.0) double successRate,
    TransactionSummary? summary,
  }) = _TransactionListResponse;
  factory TransactionListResponse.fromJson(Map<String, dynamic> json) =>
      _$TransactionListResponseFromJson(json);
}

// NOTE: Old embedded ProductBundle removed entirely (moved to offer_model.dart
// as the Offer class). Any imports of `transaction_model.dart show ProductBundle`
// must now import `offer_model.dart show Offer`.

// Transaction Summary — unchanged.
@freezed
abstract class TransactionSummary with _$TransactionSummary {
  const factory TransactionSummary({
    required String period,
    @Default(0) int totalTransactions,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0.0) double totalAmount,
    @Default(0.0) double totalCommission,
    @Default(0.0) double successRate,
    @Default(0.0) double averageTransactionValue,
    List<Map<String, dynamic>>? topOffers, // renamed from topProducts
    Map<String, int>? hourlyDistribution,
  }) = _TransactionSummary;
  factory TransactionSummary.fromJson(Map<String, dynamic> json) =>
      _$TransactionSummaryFromJson(json);
}

// Transaction Statistics — unchanged.
@freezed
abstract class TransactionStatistics with _$TransactionStatistics {
  const factory TransactionStatistics({
    @Default(0) int totalTransactions,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0) int pendingTransactions,
    @Default(0.0) double totalAmount,
    @Default(0.0) double totalCommission,
    required Map<String, int> transactionsByType,
    required Map<String, int> transactionsByDay,
    DateTime? startDate,
    DateTime? endDate,
    double? averageTransactionValue,
    double? averageSuccessRate,
  }) = _TransactionStatistics;
  factory TransactionStatistics.fromJson(Map<String, dynamic> json) =>
      _$TransactionStatisticsFromJson(json);
}

// Retry Request — unchanged.
@freezed
abstract class RetryRequest with _$RetryRequest {
  const factory RetryRequest({
    required String transactionId,
    required String agentId,
    required String deviceId,
    String? newUssdCode,
    Map<String, dynamic>? overrideParams,
  }) = _RetryRequest;
  factory RetryRequest.fromJson(Map<String, dynamic> json) =>
      _$RetryRequestFromJson(json);
}

// USSD Health Check — unchanged (kept intact per Q3 default).
@freezed
abstract class UssdHealthCheck with _$UssdHealthCheck {
  const factory UssdHealthCheck({
    @JsonKey(unknownEnumValue: UssdStatus.red)
    required UssdStatus status,
    required DateTime lastChecked,
    @Default('') String message,
    @Default(0) int responseTimeMs,
    @Default(0.0) double successRate,
    @Default(0) int totalChecks,
    @Default(0) int failedChecks,
    Map<String, dynamic>? details,
  }) = _UssdHealthCheck;
  factory UssdHealthCheck.fromJson(Map<String, dynamic> json) =>
      _$UssdHealthCheckFromJson(json);
}

// Extension: convert TransactionDetails → Transaction. Updated field references.
extension TransactionDetailsExtension on TransactionDetails {
  Transaction toTransaction() {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      recipientPhone: customerPhone,
      status: status,
      createdAt: createdAt,
      updatedAt: completedAt,
      referenceId: safaricomReference,
      description: offerName,
      note: errorMessage,
      commission: commission,
      agentId: agentId,
      offerName: offerName,
      subscriptionPlanId: subscriptionPlanId,
      balanceAfter: balanceAfter,
    );
  }
}

// Extension: convert TransactionResponse → Transaction. Old version sniffed
// productName for type — that hack is gone; type must come from the caller
// (it's not in the response payload). For W1 there's no caller of this
// extension after transaction_execution_provider is deleted; kept as a
// no-op shim so any stragglers compile, with type defaulting to .data.
extension TransactionResponseExtension on TransactionResponse {
  Transaction toTransaction({String? agentId, TransactionType type = TransactionType.data}) {
    return Transaction(
      id: transactionId,
      type: type,
      amount: amount,
      recipientPhone: customerPhone ?? '',
      status: status,
      createdAt: timestamp,
      updatedAt: timestamp,
      referenceId: reference,
      description: offerName,
      note: errorMessage,
      commission: commission,
      agentId: agentId,
      offerName: offerName,
      balanceAfter: balanceAfter,
    );
  }
}

// UI state helper — unchanged.
class TransactionUiState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  TransactionUiState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });
  TransactionUiState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return TransactionUiState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// Filter helper — unchanged.
TransactionFilter createTransactionFilter({
  int page = 1,
  int limit = 20,
  String filter = 'all',
  String period = 'today',
}) {
  List<TransactionStatus>? statuses;
  if (filter == 'success') {
    statuses = [TransactionStatus.success];
  } else if (filter == 'failed') {
    statuses = [TransactionStatus.failed, TransactionStatus.aborted];
  } else if (filter == 'pending') {
    statuses = [
      TransactionStatus.pending,
      TransactionStatus.initiated,
      TransactionStatus.validated,
      TransactionStatus.executing,
    ];
  }
  DateTime? startDate;
  DateTime? endDate;
  final now = DateTime.now();
  switch (period) {
    case 'today':
      startDate = DateTime(now.year, now.month, now.day);
      endDate = now;
      break;
    case 'week':
      startDate = now.subtract(const Duration(days: 7));
      endDate = now;
      break;
    case 'month':
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
      break;
    case 'all':
    default:
      break;
  }
  return TransactionFilter(
    page: page,
    pageSize: limit,
    statuses: statuses,
    startDate: startDate,
    endDate: endDate,
  );
}