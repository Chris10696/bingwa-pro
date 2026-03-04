import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/report_model.dart';
import '../../../../shared/repositories/reports_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Reports State
class ReportsState {
  final bool isLoading;
  final String? error;
  final ReportPeriod selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final TransactionSummary? summary;
  final List<ProductPerformance> topProducts;
  final List<DailyTransactionStats> dailyStats;
  final List<HourlyDistribution> hourlyDistribution;
  final List<TopCustomer> topCustomers;
  final ReportData? reportData;
  
  // Chart data derived from stats
  final List<ChartSeries> charts;

  ReportsState({
    this.isLoading = false,
    this.error,
    this.selectedPeriod = ReportPeriod.today,
    this.customStartDate,
    this.customEndDate,
    this.summary,
    this.topProducts = const [],
    this.dailyStats = const [],
    this.hourlyDistribution = const [],
    this.topCustomers = const [],
    this.reportData,
    List<ChartSeries>? charts,
  }) : charts = charts ?? _generateCharts(dailyStats, hourlyDistribution, topProducts);

  ReportsState copyWith({
    bool? isLoading,
    String? error,
    ReportPeriod? selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
    TransactionSummary? summary,
    List<ProductPerformance>? topProducts,
    List<DailyTransactionStats>? dailyStats,
    List<HourlyDistribution>? hourlyDistribution,
    List<TopCustomer>? topCustomers,
    ReportData? reportData,
    List<ChartSeries>? charts,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      summary: summary ?? this.summary,
      topProducts: topProducts ?? this.topProducts,
      dailyStats: dailyStats ?? this.dailyStats,
      hourlyDistribution: hourlyDistribution ?? this.hourlyDistribution,
      topCustomers: topCustomers ?? this.topCustomers,
      reportData: reportData ?? this.reportData,
      charts: charts ?? _generateCharts(
        dailyStats ?? this.dailyStats,
        hourlyDistribution ?? this.hourlyDistribution,
        topProducts ?? this.topProducts,
      ),
    );
  }

  static List<ChartSeries> _generateCharts(
    List<DailyTransactionStats> dailyStats,
    List<HourlyDistribution> hourlyDistribution,
    List<ProductPerformance> topProducts,
  ) {
    final charts = <ChartSeries>[];
    
    // Daily trend chart
    if (dailyStats.isNotEmpty) {
      charts.add(ChartSeries(
        name: 'Daily Trend',
        dataPoints: dailyStats.map((stat) => ChartDataPoint(
          label: DateFormat('MM/dd').format(stat.date),
          value: stat.totalAmount,
        )).toList(),
      ));
    }
    
    // Hourly distribution chart
    if (hourlyDistribution.isNotEmpty) {
      charts.add(ChartSeries(
        name: 'Hourly Distribution',
        dataPoints: hourlyDistribution.map((dist) => ChartDataPoint(
          label: '${dist.hour}:00',
          value: dist.transactionCount.toDouble(),
        )).toList(),
      ));
    }
    
    // Product performance chart
    if (topProducts.isNotEmpty) {
      charts.add(ChartSeries(
        name: 'Top Products',
        dataPoints: topProducts.take(5).map((product) => ChartDataPoint(
          label: product.productName.length > 10 
              ? '${product.productName.substring(0, 10)}...' 
              : product.productName,
          value: product.revenue,
        )).toList(),
      ));
    }
    
    return charts;
  }
}

// Reports Notifier
class ReportsNotifier extends StateNotifier<ReportsState> {
  final ReportsRepository _repository;
  final Ref _ref;

  ReportsNotifier(this._repository, this._ref) : super(ReportsState());

  // Load report data for selected period
  Future<void> loadReportData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id;
      
      final filter = ReportFilter(
        period: state.selectedPeriod,
        startDate: state.customStartDate,
        endDate: state.customEndDate,
        agentId: agentId,
        limit: 10,
      );

      // Load all report data in parallel
      final results = await Future.wait([
        _repository.getTransactionSummary(filter),
        _repository.getTopProducts(filter),
        _repository.getDailyStats(filter),
        _repository.getHourlyDistribution(filter),
        _repository.getTopCustomers(filter),
      ], eagerError: true);

      state = state.copyWith(
        isLoading: false,
        summary: results[0] as TransactionSummary,
        topProducts: results[1] as List<ProductPerformance>,
        dailyStats: results[2] as List<DailyTransactionStats>,
        hourlyDistribution: results[3] as List<HourlyDistribution>,
        topCustomers: results[4] as List<TopCustomer>,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load report data: ${e.toString()}',
      );
    }
  }

  // Change period
  Future<void> changePeriod(ReportPeriod period) async {
    state = state.copyWith(
      selectedPeriod: period,
      customStartDate: null,
      customEndDate: null,
    );
    await loadReportData();
  }

  // Set custom date range
  Future<void> setCustomDateRange(DateTime start, DateTime end) async {
    state = state.copyWith(
      selectedPeriod: ReportPeriod.custom,
      customStartDate: start,
      customEndDate: end,
    );
    await loadReportData();
  }

  // Refresh data
  Future<void> refresh() async {
    await loadReportData();
  }

  // Export as CSV
  Future<String?> exportCsv() async {
    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id;
      
      final filter = ReportFilter(
        period: state.selectedPeriod,
        startDate: state.customStartDate,
        endDate: state.customEndDate,
        agentId: agentId,
        limit: 1000,
      );

      return await _repository.exportReportCsv(filter);
    } catch (e) {
      state = state.copyWith(error: 'Export failed: ${e.toString()}');
      return null;
    }
  }

  // Export as PDF
  Future<String?> exportPdf() async {
    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id;
      
      final filter = ReportFilter(
        period: state.selectedPeriod,
        startDate: state.customStartDate,
        endDate: state.customEndDate,
        agentId: agentId,
        limit: 1000,
      );

      return await _repository.exportReportPdf(filter);
    } catch (e) {
      state = state.copyWith(error: 'Export failed: ${e.toString()}');
      return null;
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Format currency
  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KES ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Format number
  String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  // Format percentage
  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

// Provider
final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  final repository = ref.read(reportsRepositoryProvider);
  return ReportsNotifier(repository, ref);
});