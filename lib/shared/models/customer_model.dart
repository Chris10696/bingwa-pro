// lib/shared/models/customer_model.dart
//
// W4-batch-3b — reshaped to Hybrid-minimal (matches the backend customers entity:
// id, agentId, name, phone, accountBalance, lastPurchaseTime, isSavedInContacts,
// isBlackListed). The legacy e-commerce shape (fullName/dateOfBirth/summary/…) is gone;
// it backed a phantom UI calling endpoints that never existed.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer_model.freezed.dart';
part 'customer_model.g.dart';

@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String agentId,
    @Default('') String name,
    required String phone,
    @Default(0.0) double accountBalance,
    DateTime? lastPurchaseTime,
    @Default(false) bool isSavedInContacts,
    @Default(false) bool isBlackListed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
}

/// List query: free-text search and/or a blacklisted filter. The backend returns up
/// to 200 rows ordered by lastPurchaseTime desc (no client pagination needed).
@freezed
abstract class CustomerFilter with _$CustomerFilter {
  const factory CustomerFilter({
    String? searchTerm,
    bool? isBlacklisted,
  }) = _CustomerFilter;

  factory CustomerFilter.fromJson(Map<String, dynamic> json) =>
      _$CustomerFilterFromJson(json);
}

@freezed
abstract class CustomerListResponse with _$CustomerListResponse {
  const factory CustomerListResponse({
    @Default(<Customer>[]) List<Customer> customers,
    @Default(0) int total,
  }) = _CustomerListResponse;

  factory CustomerListResponse.fromJson(Map<String, dynamic> json) =>
      _$CustomerListResponseFromJson(json);
}

@freezed
abstract class CreateCustomerRequest with _$CreateCustomerRequest {
  const factory CreateCustomerRequest({
    required String phone,
    String? name,
    double? accountBalance,
  }) = _CreateCustomerRequest;

  factory CreateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCustomerRequestFromJson(json);
}

@freezed
abstract class UpdateCustomerRequest with _$UpdateCustomerRequest {
  const factory UpdateCustomerRequest({
    String? name,
    double? accountBalance,
  }) = _UpdateCustomerRequest;

  factory UpdateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCustomerRequestFromJson(json);
}
