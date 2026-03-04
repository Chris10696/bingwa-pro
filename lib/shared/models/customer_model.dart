import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer_model.freezed.dart';
part 'customer_model.g.dart';

// Customer Model
@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String agentId,
    required String fullName,
    required String phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? idNumber,
    String? location,
    @Default(false) bool isBlacklisted,
    DateTime? blacklistedAt,
    String? blacklistReason,
    @Default(0) int totalTransactions,
    @Default(0.0) double totalSpent,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    DateTime? firstTransactionAt,
    DateTime? lastTransactionAt,
    @Default([]) List<String> favoriteProducts,
    String? notes,
    Map<String, dynamic>? metadata,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
}

// Customer Transaction Summary
@freezed
abstract class CustomerTransactionSummary with _$CustomerTransactionSummary {
  const factory CustomerTransactionSummary({
    required String customerId,
    required String customerName,
    required String customerPhone,
    @Default(0) int totalTransactions,
    @Default(0.0) double totalSpent,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0.0) double averageTransactionValue,
    DateTime? lastTransactionDate,
    double? lastTransactionAmount,
    String? lastTransactionType,
    @Default([]) List<Map<String, dynamic>> recentTransactions,
  }) = _CustomerTransactionSummary;

  factory CustomerTransactionSummary.fromJson(Map<String, dynamic> json) =>
      _$CustomerTransactionSummaryFromJson(json);
}

// Customer Create Request
@freezed
abstract class CreateCustomerRequest with _$CreateCustomerRequest {
  const factory CreateCustomerRequest({
    required String fullName,
    required String phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? idNumber,
    String? location,
    String? notes,
  }) = _CreateCustomerRequest;

  factory CreateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCustomerRequestFromJson(json);
}

// Customer Update Request
@freezed
abstract class UpdateCustomerRequest with _$UpdateCustomerRequest {
  const factory UpdateCustomerRequest({
    String? fullName,
    String? phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? idNumber,
    String? location,
    String? notes,
  }) = _UpdateCustomerRequest;

  factory UpdateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCustomerRequestFromJson(json);
}

// Blacklist Request
@freezed
abstract class BlacklistRequest with _$BlacklistRequest {
  const factory BlacklistRequest({
    required String customerId,
    required String reason,
  }) = _BlacklistRequest;

  factory BlacklistRequest.fromJson(Map<String, dynamic> json) =>
      _$BlacklistRequestFromJson(json);
}

// Customer Filter
@freezed
abstract class CustomerFilter with _$CustomerFilter {
  const factory CustomerFilter({
    String? searchTerm,
    bool? isBlacklisted,
    DateTime? createdAfter,
    DateTime? createdBefore,
    @Default(1) int page,
    @Default(20) int pageSize,
    @Default('createdAt') String sortBy,
    @Default(false) bool sortDesc,
  }) = _CustomerFilter;

  factory CustomerFilter.fromJson(Map<String, dynamic> json) =>
      _$CustomerFilterFromJson(json);
}

// Customer List Response
@freezed
abstract class CustomerListResponse with _$CustomerListResponse {
  const factory CustomerListResponse({
    required List<Customer> customers,
    required int totalCount,
    required int page,
    required int pageSize,
    required bool hasNextPage,
  }) = _CustomerListResponse;

  factory CustomerListResponse.fromJson(Map<String, dynamic> json) =>
      _$CustomerListResponseFromJson(json);
}