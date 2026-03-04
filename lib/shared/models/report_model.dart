import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_model.freezed.dart';
part 'report_model.g.dart';

// Report Period
enum ReportPeriod {
  @JsonValue('TODAY')
  today,
  @JsonValue('WEEK')
  week,
  @JsonValue('MONTH')
  month,
  @JsonValue('YEAR')
  year,
  @JsonValue('CUSTOM')
  custom,
}

// Transaction Summary
@freezed
abstract class TransactionSummary with _$TransactionSummary {
  const factory TransactionSummary({
    required String period,
    required DateTime startDate,
    required DateTime endDate,
    @Default(0) int totalTransactions,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0) int pendingTransactions,
    @Default(0.0) double totalAmount,
    @Default(0.0) double totalCommission,
    @Default(0.0) double successRate,
    @Default(0.0) double averageTransactionValue,
  }) = _TransactionSummary;

  factory TransactionSummary.fromJson(Map<String, dynamic> json) =>
      _$TransactionSummaryFromJson(json);
}

// Product Performance
@freezed
abstract class ProductPerformance with _$ProductPerformance {
  const factory ProductPerformance({
    required String productId,
    required String productName,
    required String productType,
    @Default(0) int unitsSold,
    @Default(0.0) double revenue,
    @Default(0.0) double commission,
    @Default(0.0) double successRate,
  }) = _ProductPerformance;

  factory ProductPerformance.fromJson(Map<String, dynamic> json) =>
      _$ProductPerformanceFromJson(json);
}

// Agent Performance
@freezed
abstract class AgentPerformance with _$AgentPerformance {
  const factory AgentPerformance({
    required String agentId,
    required String agentName,
    required String agentPhone,
    @Default(0) int totalTransactions,
    @Default(0.0) double totalRevenue,
    @Default(0.0) double totalCommission,
    @Default(0.0) double successRate,
  }) = _AgentPerformance;

  factory AgentPerformance.fromJson(Map<String, dynamic> json) =>
      _$AgentPerformanceFromJson(json);
}

// Daily Transaction Stats
@freezed
abstract class DailyTransactionStats with _$DailyTransactionStats {
  const factory DailyTransactionStats({
    required DateTime date,
    @Default(0) int transactionCount,
    @Default(0.0) double totalAmount,
    @Default(0.0) double totalCommission,
    @Default(0) int successfulCount,
    @Default(0) int failedCount,
  }) = _DailyTransactionStats;

  factory DailyTransactionStats.fromJson(Map<String, dynamic> json) =>
      _$DailyTransactionStatsFromJson(json);
}

// Hourly Distribution
@freezed
abstract class HourlyDistribution with _$HourlyDistribution {
  const factory HourlyDistribution({
    required int hour,
    @Default(0) int transactionCount,
    @Default(0.0) double totalAmount,
  }) = _HourlyDistribution;

  factory HourlyDistribution.fromJson(Map<String, dynamic> json) =>
      _$HourlyDistributionFromJson(json);
}

// Top Customer
@freezed
abstract class TopCustomer with _$TopCustomer {
  const factory TopCustomer({
    required String customerId,
    required String customerName,
    required String customerPhone,
    @Default(0) int transactionCount,
    @Default(0.0) double totalSpent,
  }) = _TopCustomer;

  factory TopCustomer.fromJson(Map<String, dynamic> json) =>
      _$TopCustomerFromJson(json);
}

// Report Data
@freezed
abstract class ReportData with _$ReportData {
  const factory ReportData({
    required TransactionSummary summary,
    required List<ProductPerformance> topProducts,
    required List<DailyTransactionStats> dailyStats,
    required List<HourlyDistribution> hourlyDistribution,
    required List<TopCustomer> topCustomers,
    @Default([]) List<AgentPerformance> agentPerformance,
    Map<String, dynamic>? metadata,
  }) = _ReportData;

  factory ReportData.fromJson(Map<String, dynamic> json) =>
      _$ReportDataFromJson(json);
}

// Report Filter
@freezed
abstract class ReportFilter with _$ReportFilter {
  const factory ReportFilter({
    required ReportPeriod period,
    DateTime? startDate,
    DateTime? endDate,
    String? agentId,
    String? productType,
    @Default(10) int limit,
  }) = _ReportFilter;

  factory ReportFilter.fromJson(Map<String, dynamic> json) =>
      _$ReportFilterFromJson(json);
}

// Chart Data Point
class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;

  ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
  });
}

// Chart Series
class ChartSeries {
  final String name;
  final List<ChartDataPoint> dataPoints;

  ChartSeries({
    required this.name,
    required this.dataPoints,
  });
}