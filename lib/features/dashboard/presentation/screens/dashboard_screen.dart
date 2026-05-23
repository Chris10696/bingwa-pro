// lib/features/dashboard/presentation/screens/dashboard_screen.dart
// W1 edits:
//   - Removed Quick Actions grid entirely (Q1) — _buildQuickActions, _buildActionButton,
//     _showQRPaymentDialog all deleted
//   - Replaced "Token Balance" KES column with stacked plan-status readout (Q2):
//     Unlimited: Xd Yh / Tokens: N / No active plan
//   - Removed Popular Products section — references dropped ProductBundle type
//   - _buildTransactionItem icon switch updated for new TransactionType enum
//   - _buildProductDetails removed (no callers after Popular Products gone)
//   - Wired TokenBalanceIndicator into GradientAppBar.actions
// Debug test panel (kDebugMode-gated) retained unchanged — primer doesn't touch
// the Kotlin side; the panel becomes inert until W3 ships the new USSD pipeline.
import 'package:bingwa_pro/features/dashboard/presentation/providers/processing_provider.dart';
import 'package:bingwa_pro/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:bingwa_pro/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/token_balance_indicator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/security/secure_storage_manager.dart';
import '../providers/dashboard_provider.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../../shared/models/subscription_plan_model.dart';
import '../../../../shared/models/subscription_package_model.dart' show SubscriptionType;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  bool _showScrollTopButton = false;
  static const _testChannel = MethodChannel('bingwa_pro/test');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardNotifierProvider.notifier).loadDashboardData();
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && !_showScrollTopButton) {
      setState(() => _showScrollTopButton = true);
    } else if (_scrollController.offset <= 100 && _showScrollTopButton) {
      setState(() => _showScrollTopButton = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Test payment injection (kDebugMode only) — unchanged from prior version
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _injectTestPayment({bool dryRun = true}) async {
    try {
      await _testChannel.invokeMethod<Map>('injectTestPayment', {
        'amount': '20',
        'customerPhone': '0712345678',
        'tillNumber': '600584',
        'transactionId': 'TESTAA0001',
        'dryRun': dryRun,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dryRun
                ? '🧪 Dry-run injected — check Logcat | filter: MpesaListener, UssdEngine'
                : '🚀 Live injection sent — watch dialler for *180*5*2*0712345678*6*1#',
          ),
          backgroundColor: dryRun ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Injection error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTestInjectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.orange),
            SizedBox(width: 8),
            Text('Test USSD Engine'),
          ],
        ),
        content: const Text(
          'Choose test mode:\n\n'
          '• DRY RUN — Logs the USSD code that would be dialled. '
          'No dialler opens. Works with zero airtime.\n\n'
          '• LIVE — Actually dials *180*5*2*0712345678*6*1#. '
          'Requires CALL_PHONE permission and airtime on your SIM.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _injectTestPayment(dryRun: true);
            },
            icon: const Icon(Icons.science_outlined, color: Colors.orange),
            label: const Text('Dry Run',
                style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _injectTestPayment(dryRun: false);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Live'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);

    if (state.isLoading && state.agent == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading dashboard...'),
      );
    }

    // Read hasUsableTokens from wallet provider so the app-bar indicator can
    // react to subscription state without dashboard_provider tracking it.
    final hasUsableTokens = ref.watch(walletNotifierProvider.select(
      (s) => s.balance?.hasUsableTokens ?? false,
    ));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: GradientAppBar(
        title: 'Dashboard',
        actions: [
          TokenBalanceIndicator(hasUsableTokens: hasUsableTokens),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(state),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildTopStats(state)),
            if (state.showHealthWarning)
              SliverToBoxAdapter(child: _buildHealthWarning(state)),
            if (kDebugMode) SliverToBoxAdapter(child: _buildTestPanel()),
            SliverPersistentHeader(
              delegate: _TabBarDelegate(_tabController),
              pinned: true,
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(state, notifier),
                  _buildTransactionsTab(state),
                  _buildAnalyticsTab(state),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildProcessingFAB(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Debug test panel (kDebugMode only) — unchanged
  Widget _buildTestPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text(
                'DEBUG — USSD Engine Test',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Injects a fake KES 20 payment → routes to 250mb_24hrs → '
            'builds USSD code *180*5*2*0712345678*6*1#. '
            'Watch Logcat: filter by "MpesaListener" and "UssdEngine".',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _injectTestPayment(dryRun: true),
                  icon: const Icon(Icons.science_outlined,
                      size: 16, color: Colors.orange),
                  label: const Text('Dry Run',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showTestInjectionDialog,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Inject Live',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Processing FAB — unchanged
  Widget _buildProcessingFAB() {
    final processingState = ref.watch(processingProvider);
    final processingNotifier = ref.read(processingProvider.notifier);
    if (processingState.status == ProcessingStatus.running) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBadge(
            Colors.green,
            'Processing: ${processingState.transactionsProcessed} txns',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'pause',
            onPressed: () => processingNotifier.pauseProcessing(),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.pause),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'stop',
            onPressed: () => processingNotifier.stopProcessing(),
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          ),
        ],
      );
    }
    if (processingState.status == ProcessingStatus.paused) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBadge(Colors.orange, 'Paused'),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'resume',
            onPressed: () => processingNotifier.startProcessing(),
            backgroundColor: const Color(0xFF00C853),
            child: const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'stopFromPause',
            onPressed: () => processingNotifier.stopProcessing(),
            backgroundColor: Colors.red,
            mini: true,
            child: const Icon(Icons.stop),
          ),
        ],
      );
    }
    return FloatingActionButton(
      heroTag: 'start',
      onPressed: () => processingNotifier.startProcessing(),
      backgroundColor: const Color(0xFF00C853),
      child: const Icon(Icons.play_arrow),
    );
  }

  Widget _buildStatusBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Drawer — unchanged (all destinations route to surviving screens)
  Widget _buildDrawer(DashboardState state) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              state.agent?.fullName ?? 'Agent',
              style: const TextStyle(fontSize: 18),
            ),
            accountEmail: Text(
              state.agent?.phoneNumber ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                state.agent?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C853),
                ),
              ),
            ),
            decoration: const BoxDecoration(color: Color(0xFF00C853)),
          ),
          _drawerSection('MAIN'),
          _drawerItem(Icons.dashboard, 'Dashboard', Colors.green,
              () => Navigator.pop(context)),
          _drawerItem(Icons.account_balance_wallet, 'Wallet', Colors.blue, () {
            Navigator.pop(context);
            context.push('/wallet');
          }),
          _drawerItem(Icons.local_offer, 'Offers', Colors.orange, () {
            Navigator.pop(context);
            context.push('/offers');
          }),
          _drawerItem(Icons.history, 'Transaction History', Colors.purple, () {
            Navigator.pop(context);
            context.push('/transaction-history');
          }),
          const Divider(),
          _drawerSection('TOOLS'),
          _drawerItem(Icons.speed, 'Quick Dial', Colors.teal, () {
            Navigator.pop(context);
            context.push('/quick-dial');
          }),
          _drawerItem(Icons.autorenew, 'Auto Renewals', Colors.indigo, () {
            Navigator.pop(context);
            context.push('/auto-renewals');
          }),
          _drawerItem(Icons.link, 'SiteLink', Colors.lightBlue, () {
            Navigator.pop(context);
            context.push('/sitelink');
          }),
          _drawerItem(
              Icons.message, 'Auto-Reply Messages', Colors.deepPurple, () {
            Navigator.pop(context);
            context.push('/auto-reply');
          }),
          const Divider(),
          _drawerSection('MANAGEMENT'),
          _drawerItem(Icons.people, 'Customers', Colors.teal, () {
            Navigator.pop(context);
            context.push('/customers');
          }),
          _drawerItem(Icons.bar_chart, 'Reports', Colors.indigo, () {
            Navigator.pop(context);
            context.push('/reports');
          }),
          const Divider(),
          _drawerSection('SUPPORT'),
          _drawerItem(Icons.settings, 'Settings', Colors.grey, () {
            Navigator.pop(context);
            context.push('/settings');
          }),
          _drawerItem(Icons.help, 'Help & Support', Colors.grey, () {
            Navigator.pop(context);
            context.push('/help');
          }),
          const Divider(),
          _drawerItem(Icons.logout, 'Logout', Colors.red, _confirmLogout),
        ],
      ),
    );
  }

  Widget _drawerSection(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );

  Widget _drawerItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Top stats card — REPLACED "Token Balance KES" with plan-status readout (Q2)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopStats(DashboardState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      margin: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${state.agent?.fullName.split(' ').first ?? 'Agent'}!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlanStatus(state.walletBalance?.plans ?? const []),
              _buildUssdHealthIndicator(state.ussdHealth),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today Sales',
                  Formatters.formatCurrency(state.stats?.todaySales ?? 0),
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  '${((state.stats?.successRate ?? 0) * 100).toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Commission',
                  Formatters.formatCurrency(state.stats?.todayCommission ?? 0),
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Q2 plan-status readout. Stacks Unlimited and Limited if both active.
  /// Shows "No active plan" if neither, with a Subscribe button to /wallet.
  Widget _buildPlanStatus(List<SubscriptionPlan> plans) {
    final unlimited = plans.firstWhere(
      (p) =>
          p.type == SubscriptionType.unlimited &&
          p.isActive &&
          p.expiresAt != null &&
          p.expiresAt!.isAfter(DateTime.now()),
      orElse: () => _emptyPlan(),
    );
    final limited = plans.firstWhere(
      (p) =>
          p.type == SubscriptionType.limited &&
          p.isActive &&
          (p.tokensRemaining ?? 0) > 0,
      orElse: () => _emptyPlan(),
    );

    final hasUnlimited = unlimited.id != _emptyPlanId;
    final hasLimited = limited.id != _emptyPlanId;

    if (!hasUnlimited && !hasLimited) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          const Text(
            'No active plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => context.push('/wallet'),
            child: const Text(
              'Subscribe',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C853),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscription',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        if (hasUnlimited)
          Text(
            'Unlimited: ${_formatRemainingDuration(unlimited.expiresAt!)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00C853),
            ),
          ),
        if (hasLimited)
          Padding(
            padding: EdgeInsets.only(top: hasUnlimited ? 2.0 : 0.0),
            child: Text(
              'Tokens: ${limited.tokensRemaining}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C853),
              ),
            ),
          ),
      ],
    );
  }

  // Sentinel for the firstWhere orElse pattern above.
  static const _emptyPlanId = '___EMPTY___';
  SubscriptionPlan _emptyPlan() => SubscriptionPlan(
        id: _emptyPlanId,
        agentId: '',
        type: SubscriptionType.limited,
        purchasedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isActive: false,
      );

  /// Formats remaining duration as Xd Yh, falling back to smaller units.
  String _formatRemainingDuration(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days >= 1) return '${days}d ${hours}h';
    if (hours >= 1) return '${hours}h ${minutes}m';
    if (minutes >= 1) return '${minutes}m';
    return '<1m';
  }

  Widget _buildHealthWarning(DashboardState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 244, 229),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromARGB(255, 255, 204, 128)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  state.ussdHealth?.message ??
                      'USSD system experiencing issues',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showHealthDetails(state.ussdHealth),
            child: const Text('Details',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showHealthDetails(UssdHealthCheck? health) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('USSD System Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status',
                health?.status.toString().split('.').last ?? 'Unknown'),
            _buildDetailRow(
              'Success Rate',
              '${((health?.successRate ?? 0) * 100).toStringAsFixed(1)}%',
            ),
            _buildDetailRow(
                'Response Time', '${health?.responseTimeMs ?? 0}ms'),
            _buildDetailRow(
              'Last Check',
              health?.lastChecked != null
                  ? DateFormat('HH:mm:ss').format(health!.lastChecked)
                  : 'Never',
            ),
            const SizedBox(height: 16),
            Text(health?.message ?? 'No additional information'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildUssdHealthIndicator(UssdHealthCheck? health) {
    Color color;
    IconData icon;
    String status;
    switch (health?.status) {
      case UssdStatus.green:
        color = Colors.green;
        icon = Icons.check_circle;
        status = 'Normal';
        break;
      case UssdStatus.yellow:
        color = Colors.orange;
        icon = Icons.warning;
        status = 'Degraded';
        break;
      case UssdStatus.red:
        color = Colors.red;
        icon = Icons.error;
        status = 'Critical';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        status = 'Unknown';
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(fontSize: 12, color: color)),
          ]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tabs — Quick Actions + Popular Products removed from Overview tab
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(DashboardState state, DashboardNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildRecentTransactions(state),
        const SizedBox(height: 20),
        _buildPerformanceChart(state),
      ],
    );
  }

  Widget _buildTransactionsTab(DashboardState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Transactions Tab',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('View detailed transaction list',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/transaction-history'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853)),
            child: const Text('View All Transactions'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(DashboardState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Analytics Tab',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Advanced analytics coming soon',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Recent transactions section
  Widget _buildRecentTransactions(DashboardState state) {
    final transactions = state.recentTransactions ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.push('/transaction-history'),
              child: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF00C853)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(children: [
              Icon(Icons.receipt_long, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text('No transactions yet',
                  style: TextStyle(color: Colors.grey)),
            ]),
          )
        else
          ...transactions.map(_buildTransactionItem),
      ],
    );
  }

  Widget _buildTransactionItem(TransactionDetails transaction) {
    final isSuccess = transaction.status == TransactionStatus.success;
    // W1: icon switch updated for new TransactionType enum
    IconData icon;
    switch (transaction.type) {
      case TransactionType.quickDial:
        icon = Icons.phone_forwarded;
        break;
      case TransactionType.mpesa:
        icon = Icons.payments;
        break;
      case TransactionType.till:
        icon = Icons.point_of_sale;
        break;
      case TransactionType.siteLink:
        icon = Icons.link;
        break;
      case TransactionType.subscriptionRenewal:
        icon = Icons.autorenew;
        break;
      case TransactionType.airtimeBalanceCheck:
        icon = Icons.account_balance_wallet;
        break;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isSuccess ? Colors.green : Colors.red),
        ),
        title: Text(
          transaction.type.name.toUpperCase().replaceAll('_', ' '),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.customerPhone),
            Text(Formatters.formatDateTime(transaction.createdAt),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.formatCurrency(transaction.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isSuccess ? Colors.green : Colors.red)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                transaction.status.name,
                style: TextStyle(
                  fontSize: 10,
                  color: isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  void _showTransactionDetails(TransactionDetails transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Reference', transaction.safaricomReference ?? transaction.id),
              _buildDetailRow('Type', transaction.type.name.toUpperCase()),
              _buildDetailRow(
                  'Amount', Formatters.formatCurrency(transaction.amount)),
              _buildDetailRow('Customer', transaction.customerPhone),
              _buildDetailRow('Status', transaction.status.name.toUpperCase()),
              _buildDetailRow(
                  'Date', Formatters.formatDateTime(transaction.createdAt)),
              if (transaction.completedAt != null)
                _buildDetailRow(
                  'Completed',
                  Formatters.formatDateTime(transaction.completedAt!),
                ),
              if (transaction.tokenAmount > 0)
                _buildDetailRow('Tokens', transaction.tokenAmount.toString()),
              if (transaction.commission > 0)
                _buildDetailRow(
                    'Commission', Formatters.formatCurrency(transaction.commission)),
              if (transaction.balanceAfter != null)
                _buildDetailRow('Balance After',
                    Formatters.formatCurrency(transaction.balanceAfter!)),
              if (transaction.errorMessage != null)
                _buildDetailRow('Error', transaction.errorMessage!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (transaction.status == TransactionStatus.failed)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                BuildContext? loadCtx;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) {
                    loadCtx = c;
                    return const Center(child: CircularProgressIndicator());
                  },
                );
                final success = await ref
                    .read(transactionProvider.notifier)
                    .retryTransaction(transaction.id);
                if (!mounted) return;
                if (loadCtx != null) Navigator.pop(loadCtx!);
                final txState = ref.read(transactionProvider);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    success != null
                        ? (txState.retrySuccessMessage ??
                            'Retried successfully')
                        : (txState.retryError ?? 'Retry failed'),
                  ),
                  backgroundColor:
                      success != null ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 3),
                ));
                if (success != null) {
                  await ref
                      .read(dashboardNotifierProvider.notifier)
                      .refresh();
                }
                ref.read(transactionProvider.notifier).clearRetryMessages();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  // Performance chart — unchanged (uses placeholder data; W5 wires real backend data)
  Widget _buildPerformanceChart(DashboardState state) {
    final weekData = [12000.0, 15000.0, 8000.0, 22000.0, 18000.0, 25000.0, 20000.0];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Performance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: state.selectedPeriod,
                items: const [
                  DropdownMenuItem(value: 'TODAY', child: Text('Today')),
                  DropdownMenuItem(value: 'WEEK', child: Text('This Week')),
                  DropdownMenuItem(value: 'MONTH', child: Text('This Month')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(dashboardNotifierProvider.notifier)
                        .changePeriod(v);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 5000,
                  verticalInterval: 1,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        return i >= 0 && i < days.length
                            ? Text(days[i])
                            : const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          Text('${(value / 1000).toInt()}k'),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: weekData
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: const Color(0xFF00C853),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz), label: 'Transactions'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (index) {
        switch (index) {
          case 1:
            context.push('/transaction-history');
            break;
          case 2:
            context.push('/wallet');
            break;
          case 3:
            context.push('/profile');
            break;
        }
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              AppLogger.logSessionEvent(
                  event: 'Manual logout from dashboard');
              await SecureStorageManager.clearAll();
              if (mounted) context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController _tabController;
  _TabBarDelegate(this._tabController);
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF00C853),
        labelColor: const Color(0xFF00C853),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate _) => true;
}