import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/reports_provider.dart';
import '../../../../shared/models/report_model.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollTopButton = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(reportsProvider.notifier).loadReportData();
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 300 && !_showScrollTopButton) {
      setState(() => _showScrollTopButton = true);
    } else if (_scrollController.offset <= 300 && _showScrollTopButton) {
      setState(() => _showScrollTopButton = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Reports',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) async {
              if (value == 'csv') {
                final csv = await notifier.exportCsv();
                if (csv != null && mounted) {
                  _showExportDialog(context, 'CSV exported successfully');
                }
              } else if (value == 'pdf') {
                final pdf = await notifier.exportPdf();
                if (pdf != null && mounted) {
                  _showExportDialog(context, 'PDF exported successfully');
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingIndicator(message: 'Loading reports...')
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Period Selector
                  SliverToBoxAdapter(
                    child: _buildPeriodSelector(state, notifier),
                  ),
                  
                  // Error Message
                  if (state.error != null)
                    SliverToBoxAdapter(
                      child: _buildErrorWidget(state.error!, notifier),
                    ),
                  
                  // Summary Cards
                  if (state.summary != null)
                    SliverToBoxAdapter(
                      child: _buildSummaryCards(state),
                    ),
                  
                  // Charts
                  if (state.charts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildCharts(state),
                    ),
                  
                  // Top Products
                  if (state.topProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildTopProducts(state),
                    ),
                  
                  // Top Customers
                  if (state.topCustomers.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildTopCustomers(state),
                    ),
                  
                  // Hourly Distribution
                  if (state.hourlyDistribution.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildHourlyDistribution(state),
                    ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
      floatingActionButton: _showScrollTopButton
          ? FloatingActionButton(
              mini: true,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: const Color(0xFF00C853),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }

  Widget _buildPeriodSelector(ReportsState state, ReportsNotifier notifier) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodButton(
                    'Today',
                    ReportPeriod.today,
                    state,
                    notifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton(
                    'This Week',
                    ReportPeriod.week,
                    state,
                    notifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton(
                    'This Month',
                    ReportPeriod.month,
                    state,
                    notifier,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodButton(
                    'This Year',
                    ReportPeriod.year,
                    state,
                    notifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton(
                    'Custom',
                    ReportPeriod.custom,
                    state,
                    notifier,
                  ),
                ),
              ],
            ),
            
            // Custom date picker
            if (state.selectedPeriod == ReportPeriod.custom)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context, notifier),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                state.customStartDate != null
                                    ? DateFormat('dd MMM yyyy').format(state.customStartDate!)
                                    : 'Select',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndDate(context, notifier),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                state.customEndDate != null
                                    ? DateFormat('dd MMM yyyy').format(state.customEndDate!)
                                    : 'Select',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(
    String label,
    ReportPeriod period,
    ReportsState state,
    ReportsNotifier notifier,
  ) {
    final isSelected = state.selectedPeriod == period;
    return ElevatedButton(
      onPressed: () => notifier.changePeriod(period),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF00C853) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildErrorWidget(String error, ReportsNotifier notifier) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: notifier.clearError,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ReportsState state) {
    final summary = state.summary!;
    final notifier = ref.read(reportsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Transactions',
                  value: notifier.formatNumber(summary.totalTransactions),
                  subtitle: '${notifier.formatNumber(summary.successfulTransactions)} successful',
                  icon: Icons.receipt,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Revenue',
                  value: notifier.formatCurrency(summary.totalAmount),
                  subtitle: 'Avg: ${notifier.formatCurrency(summary.averageTransactionValue)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Commission',
                  value: notifier.formatCurrency(summary.totalCommission),
                  subtitle: '${notifier.formatPercentage(summary.successRate)} success rate',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Success Rate',
                  value: notifier.formatPercentage(summary.successRate),
                  subtitle: '${summary.failedTransactions} failed',
                  icon: Icons.check_circle,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts(ReportsState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: _buildLineChart(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(ReportsState state) {
    if (state.dailyStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final spots = state.dailyStats.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalAmount);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('KES ${(value / 1000).toInt()}k');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < state.dailyStats.length) {
                  return Text(DateFormat('dd/MM').format(state.dailyStats[index].date));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF00C853),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00C853).withValues(alpha: 0.1),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: 0,
      ),
    );
  }

  Widget _buildTopProducts(ReportsState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...state.topProducts.take(5).map((product) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getProductColor(product.productType).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getProductIcon(product.productType),
                        color: _getProductColor(product.productType),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${product.unitsSold} units sold',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(
                            symbol: 'KES ',
                            decimalDigits: 0,
                          ).format(product.revenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${(product.successRate * 100).toStringAsFixed(0)}% success',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCustomers(ReportsState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Customers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...state.topCustomers.take(5).map((customer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          customer.customerName[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            customer.customerPhone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(
                            symbol: 'KES ',
                            decimalDigits: 0,
                          ).format(customer.totalSpent),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${customer.transactionCount} transactions',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyDistribution(ReportsState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Peak Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < state.hourlyDistribution.length) {
                              return Text('${state.hourlyDistribution[index].hour}:00');
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: state.hourlyDistribution.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.transactionCount.toDouble(),
                            color: const Color(0xFF00C853),
                            width: 16,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProductColor(String productType) {
    switch (productType.toLowerCase()) {
      case 'airtime':
        return Colors.green;
      case 'data':
        return Colors.blue;
      case 'sms':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  IconData _getProductIcon(String productType) {
    switch (productType.toLowerCase()) {
      case 'airtime':
        return Icons.phone_android;
      case 'data':
        return Icons.wifi;
      case 'sms':
        return Icons.message;
      default:
        return Icons.shopping_bag;
    }
  }

  Future<void> _selectStartDate(BuildContext context, ReportsNotifier notifier) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      final endDate = notifier.state.customEndDate ?? DateTime.now();
      await notifier.setCustomDateRange(date, endDate);
    }
  }

  Future<void> _selectEndDate(BuildContext context, ReportsNotifier notifier) async {
    final startDate = notifier.state.customStartDate ?? 
        DateTime.now().subtract(const Duration(days: 7));
    
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: startDate,
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      await notifier.setCustomDateRange(startDate, date);
    }
  }

  void _showExportDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }
}