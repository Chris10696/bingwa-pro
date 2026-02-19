import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

// Transaction Types
enum TransactionType {
  @JsonValue('AIRTIME')
  airtime,
  @JsonValue('DATA')
  data,
  @JsonValue('SMS')
  sms,
  @JsonValue('MINUTES')
  minutes,
  @JsonValue('BUNDLE')
  bundle,
}

// Transaction Status
enum TransactionStatus {
  @JsonValue('INITIATED')
  initiated,
  @JsonValue('VALIDATED')
  validated,
  @JsonValue('EXECUTING')
  executing,
  @JsonValue('SUCCESS')
  success,
  @JsonValue('FAILED')
  failed,
  @JsonValue('ABORTED')
  aborted,
  @JsonValue('PENDING')
  pending,
  @JsonValue('REFUNDED')
  refunded,
  @JsonValue('DISPUTED')
  disputed,
}

// USSD Status
enum UssdStatus {
  @JsonValue('GREEN')
  green,    // All systems normal
  @JsonValue('YELLOW')
  yellow,   // Degraded performance
  @JsonValue('RED')
  red,      // System down or unstable
}

// ========== CORE TRANSACTION MODELS ==========

// Transaction Request
@freezed
abstract class TransactionRequest with _$TransactionRequest {
  const factory TransactionRequest({
    required String agentId,
    required TransactionType type,
    required String customerPhone,
    required double amount,
    required String productId,
    String? productName,
    String? bundleSize,
    int? validityDays,
    String? ussdCode,
    required String deviceId,
    String? customerName,
    String? customerEmail,
    Map<String, dynamic>? metadata,
  }) = _TransactionRequest;

  factory TransactionRequest.fromJson(Map<String, dynamic> json) =>
      _$TransactionRequestFromJson(json);
}

// Transaction Response
@freezed
abstract class TransactionResponse with _$TransactionResponse {
  const factory TransactionResponse({
    required String transactionId,
    required String reference,
    required TransactionStatus status,
    required DateTime timestamp,
    required double amount,
    required double tokenDeduction,
    required double commission,
    String? ussdResponse,
    String? safaricomReference,
    String? errorMessage,
    String? customerPhone,
    String? productName,
    double? balanceAfter,
    Map<String, dynamic>? metadata,
  }) = _TransactionResponse;

  factory TransactionResponse.fromJson(Map<String, dynamic> json) =>
      _$TransactionResponseFromJson(json);
}

// Transaction Details
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
    String? productId,
    String? productName,
    String? bundleSize,
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
  }) = _TransactionDetails;

  factory TransactionDetails.fromJson(Map<String, dynamic> json) =>
      _$TransactionDetailsFromJson(json);
}

// Simplified Transaction Model for UI (for TransactionHistoryScreen)
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
    String? productName,
    String? bundleSize,
    double? balanceAfter,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

// Transaction Filter
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

// Transaction List Response
@freezed
abstract class TransactionListResponse with _$TransactionListResponse {
  const factory TransactionListResponse({
    required List<TransactionDetails> transactions,
    required int totalCount,
    required int page,
    required int pageSize,
    required bool hasNextPage,
    TransactionSummary? summary,
  }) = _TransactionListResponse;

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) =>
      _$TransactionListResponseFromJson(json);
}

// ========== PRODUCT & BUNDLE MODELS ==========

// Product Bundle
@freezed
abstract class ProductBundle with _$ProductBundle {
  const factory ProductBundle({
    required String id,
    required String name,
    required TransactionType type,
    required double price,
    required String value, // e.g., "1GB", "100 minutes", "100 SMS"
    required int validityDays,
    required String ussdCode,
    required String network, // SAFARICOM, AIRTEL, TELKOM
    @Default(true) bool isActive,
    @Default('') String description,
    @Default(0.0) double commissionRate,
    @Default('') String category,
    int? priority,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) = _ProductBundle;

  factory ProductBundle.fromJson(Map<String, dynamic> json) =>
      _$ProductBundleFromJson(json);
}

// ========== SUMMARY & STATISTICS MODELS ==========

// Transaction Summary
@freezed
abstract class TransactionSummary with _$TransactionSummary {
  const factory TransactionSummary({
    required String period, // TODAY, THIS_WEEK, THIS_MONTH
    @Default(0) int totalTransactions,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0.0) double totalAmount,
    @Default(0.0) double totalCommission,
    @Default(0.0) double successRate,
    @Default(0.0) double averageTransactionValue,
    List<Map<String, dynamic>>? topProducts,
    Map<String, int>? hourlyDistribution,
  }) = _TransactionSummary;

  factory TransactionSummary.fromJson(Map<String, dynamic> json) =>
      _$TransactionSummaryFromJson(json);
}

// Transaction Statistics
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

// ========== RETRY & SUPPORT MODELS ==========

// Retry Request
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

// USSD Health Check
@freezed
abstract class UssdHealthCheck with _$UssdHealthCheck {
  const factory UssdHealthCheck({
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

// ========== HELPER EXTENSIONS & CONVERTERS ==========

// Extension to convert TransactionDetails to simplified Transaction
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
      description: productName,
      note: errorMessage,
      commission: commission,
      agentId: agentId,
      productName: productName,
      bundleSize: bundleSize,
      balanceAfter: balanceAfter,
    );
  }
}

// Extension to convert TransactionResponse to simplified Transaction
extension TransactionResponseExtension on TransactionResponse {
  Transaction toTransaction({String? agentId}) {
    // Map TransactionStatus to simplified status string
    final statusString = status.name.toLowerCase();
    
    return Transaction(
      id: transactionId,
      type: TransactionType.values.firstWhere(
        (type) => type.name.toLowerCase() == (productName?.toLowerCase().contains('airtime') == true 
            ? 'airtime' 
            : productName?.toLowerCase().contains('data') == true
              ? 'data'
              : productName?.toLowerCase().contains('sms') == true
                ? 'sms'
                : 'bundle'),
        orElse: () => TransactionType.bundle,
      ),
      amount: amount,
      recipientPhone: customerPhone ?? '',
      status: TransactionStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == statusString,
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: timestamp,
      updatedAt: timestamp,
      referenceId: reference,
      description: productName,
      note: errorMessage,
      commission: commission,
      agentId: agentId,
      productName: productName,
      balanceAfter: balanceAfter,
    );
  }
}

// Helper class for TransactionHistoryScreen UI state
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

// Helper method to map filter string to TransactionFilter
TransactionFilter createTransactionFilter({
  int page = 1,
  int limit = 20,
  String filter = 'all',
  String period = 'today',
}) {
  // Map filter string to status
  List<TransactionStatus>? statuses;
  if (filter == 'success') {
    statuses = [TransactionStatus.success];
  } else if (filter == 'failed') {
    statuses = [TransactionStatus.failed, TransactionStatus.aborted];
  } else if (filter == 'pending') {
    statuses = [TransactionStatus.pending, TransactionStatus.initiated, TransactionStatus.validated, TransactionStatus.executing];
  }
  // 'all' will keep statuses as null

  // Map period to date range
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
      // No date filter for 'all'
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