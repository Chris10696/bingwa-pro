// lib/shared/models/payment_notification.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_notification.freezed.dart';
part 'payment_notification.g.dart';

@freezed
abstract class PaymentNotification with _$PaymentNotification {
  const factory PaymentNotification({
    required String id,
    required String transactionId,
    required String customerPhone,
    required double amount,
    required DateTime timestamp,
    String? tillNumber,
    String? paybillNumber,
    String? accountNumber,
    String? reference,
    required String status, // 'pending', 'completed', 'failed'
    Map<String, dynamic>? metadata,
  }) = _PaymentNotification;

  factory PaymentNotification.fromJson(Map<String, dynamic> json) =>
      _$PaymentNotificationFromJson(json);
}

// Request model for checking payments
@freezed
abstract class CheckPaymentsRequest with _$CheckPaymentsRequest {
  const factory CheckPaymentsRequest({
    String? tillNumber,
    String? paybillNumber,
    DateTime? lastCheckTime,
  }) = _CheckPaymentsRequest;

  factory CheckPaymentsRequest.fromJson(Map<String, dynamic> json) =>
      _$CheckPaymentsRequestFromJson(json);
}

// Response model for payment check
@freezed
abstract class CheckPaymentsResponse with _$CheckPaymentsResponse {
  const factory CheckPaymentsResponse({
    required List<PaymentNotification> payments,
    required int count,
    DateTime? nextCheckTime,
  }) = _CheckPaymentsResponse;

  factory CheckPaymentsResponse.fromJson(Map<String, dynamic> json) =>
      _$CheckPaymentsResponseFromJson(json);
}