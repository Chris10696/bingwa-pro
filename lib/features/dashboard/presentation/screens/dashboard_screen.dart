// C:\bingwa_pro\lib\features\dashboard\presentation\screens\dashboard_screen.dart
import 'package:bingwa_pro/features/dashboard/presentation/providers/processing_provider.dart';
import 'package:bingwa_pro/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/security/secure_storage_manager.dart';
import '../providers/dashboard_provider.dart';
import '../../../../shared/models/transaction_model.dart';

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

  // ── Test channel — name must match TEST_CHANNEL in MainActivity.kt ─────────
  static const _testChannel = MethodChannel('bingwa_pro/test');
  // ─────────────────────────────────────────────────────────────────────────

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
  // Test payment injection
  //
  // dryRun: true  → only logs; dialler never opened. Works with zero airtime.
  // dryRun: false → actually dials. Needs CALL_PHONE permission + airtime.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _injectTestPayment({bool dryRun = true}) async {
    try {
      await _testChannel.invokeMethod<Map>('injectTestPayment', {
        'amount':        '20',        // KES 20 → 250mb_24hrs route
        'customerPhone': '0712345678',
        'tillNumber':    '600584',
        'transactionId': 'TESTAA0001',
        'dryRun':        dryRun,
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
          duration:        const Duration(seconds: 5),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text('Injection error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Confirmation dialog before live injection ──────────────────────────────
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
            icon:  const Icon(Icons.science_outlined, color: Colors.orange),
            label: const Text('Dry Run', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _injectTestPayment(dryRun: false);
            },
            icon:  const Icon(Icons.play_arrow),
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
    final state    = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);

    if (state.isLoading && state.agent == null) {
      return const Scaffold(body: LoadingIndicator(message: 'Loading dashboard...'));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const GradientAppBar(title: 'Dashboard', actions: []),
      drawer: _buildDrawer(state),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Stats card
            SliverToBoxAdapter(child: _buildTopStats(state)),

            // Health warning (shown only when USSD status is yellow / red)
            if (state.showHealthWarning)
              SliverToBoxAdapter(child: _buildHealthWarning(state)),

            // ── Debug-only test panel ─────────────────────────────────────
            // kDebugMode is false in release builds; this panel is never
            // shown to production users. No need to remove it before launch.
            if (kDebugMode)
              SliverToBoxAdapter(child: _buildTestPanel()),
            // ─────────────────────────────────────────────────────────────

            // Sticky tab bar
            SliverPersistentHeader(
              delegate: _TabBarDelegate(_tabController),
              pinned:   true,
            ),

            // Tab content
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
      bottomNavigationBar:  _buildBottomNavigation(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Debug test panel (kDebugMode only)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTestPanel() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(15, 0, 15, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text(
                'DEBUG — USSD Engine Test',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      Colors.orange,
                  fontSize:   13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description
          const Text(
            'Injects a fake KES 20 payment → routes to 250mb_24hrs → '
            'builds USSD code *180*5*2*0712345678*6*1#. '
            'Watch Logcat: filter by "MpesaListener" and "UssdEngine".',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              // Dry run — safe, no airtime needed
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _injectTestPayment(dryRun: true),
                  icon:  const Icon(Icons.science_outlined, size: 16, color: Colors.orange),
                  label: const Text('Dry Run', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side:            const BorderSide(color: Colors.orange),
                    padding:         const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Live — shows confirmation dialog first
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showTestInjectionDialog,
                  icon:  const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Inject Live', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:         const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Processing FAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProcessingFAB() {
    final processingState    = ref.watch(processingProvider);
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
            heroTag:         'pause',
            onPressed:       () => processingNotifier.pauseProcessing(),
            backgroundColor: Colors.orange,
            child:           const Icon(Icons.pause),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag:         'stop',
            onPressed:       () => processingNotifier.stopProcessing(),
            backgroundColor: Colors.red,
            child:           const Icon(Icons.stop),
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
            heroTag:         'resume',
            onPressed:       () => processingNotifier.startProcessing(),
            backgroundColor: const Color(0xFF00C853),
            child:           const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag:         'stopFromPause',
            onPressed:       () => processingNotifier.stopProcessing(),
            backgroundColor: Colors.red,
            mini:            true,
            child:           const Icon(Icons.stop),
          ),
        ],
      );
    }

    return FloatingActionButton(
      heroTag:         'start',
      onPressed:       () => processingNotifier.startProcessing(),
      backgroundColor: const Color(0xFF00C853),
      child:           const Icon(Icons.play_arrow),
    );
  }

  Widget _buildStatusBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:       10,
            height:      10,
            decoration:  BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Drawer
  // ─────────────────────────────────────────────────────────────────────────
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
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Color(0xFF00C853),
                ),
              ),
            ),
            decoration: const BoxDecoration(color: Color(0xFF00C853)),
          ),

          _drawerSection('MAIN'),
          _drawerItem(Icons.dashboard,              'Dashboard',           Colors.green,      () => Navigator.pop(context)),
          _drawerItem(Icons.account_balance_wallet, 'Wallet',              Colors.blue,       () { Navigator.pop(context); context.push('/wallet'); }),
          _drawerItem(Icons.local_offer,            'Offers',              Colors.orange,     () { Navigator.pop(context); context.push('/offers'); }),
          _drawerItem(Icons.history,                'Transaction History', Colors.purple,     () { Navigator.pop(context); context.push('/transaction-history'); }),

          const Divider(),
          _drawerSection('TOOLS'),
          _drawerItem(Icons.speed,      'Quick Dial',          Colors.teal,       () { Navigator.pop(context); context.push('/quick-dial'); }),
          _drawerItem(Icons.autorenew,  'Auto Renewals',       Colors.indigo,     () { Navigator.pop(context); context.push('/auto-renewals'); }),
          _drawerItem(Icons.link,       'SiteLink',            Colors.lightBlue,  () { Navigator.pop(context); context.push('/sitelink'); }),
          _drawerItem(Icons.message,    'Auto-Reply Messages', Colors.deepPurple, () { Navigator.pop(context); context.push('/auto-reply'); }),

          const Divider(),
          _drawerSection('MANAGEMENT'),
          _drawerItem(Icons.people,    'Customers', Colors.teal,  () { Navigator.pop(context); context.push('/customers'); }),
          _drawerItem(Icons.bar_chart, 'Reports',   Colors.indigo, () { Navigator.pop(context); context.push('/reports'); }),

          const Divider(),
          _drawerSection('SUPPORT'),
          _drawerItem(Icons.settings, 'Settings',       Colors.grey, () { Navigator.pop(context); context.push('/settings'); }),
          _drawerItem(Icons.help,     'Help & Support', Colors.grey, () { Navigator.pop(context); context.push('/help'); }),

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
        fontSize:   12,
        fontWeight: FontWeight.bold,
        color:      Colors.grey,
      ),
    ),
  );

  Widget _drawerItem(
    IconData     icon,
    String       title,
    Color        color,
    VoidCallback onTap,
  ) =>
      ListTile(
        leading: Icon(icon, color: color),
        title:   Text(title),
        onTap:   onTap,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Top stats card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopStats(DashboardState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 10, spreadRadius: 2),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Token Balance',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.formatCurrency(state.walletBalance?.availableBalance ?? 0),
                    style: const TextStyle(
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                      color:      Color(0xFF00C853),
                    ),
                  ),
                ],
              ),
              _buildUssdHealthIndicator(state.ussdHealth),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Today Sales',  Formatters.formatCurrency(state.stats?.todaySales ?? 0),           Icons.trending_up,  Colors.green)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Success Rate', '${((state.stats?.successRate ?? 0) * 100).toStringAsFixed(1)}%', Icons.check_circle,  Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Commission',   Formatters.formatCurrency(state.stats?.todayCommission ?? 0),      Icons.attach_money,  Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Health warning banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHealthWarning(DashboardState state) {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:        const Color.fromARGB(255, 255, 244, 229),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: const Color.fromARGB(255, 255, 204, 128)),
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                Text(
                  state.ussdHealth?.message ?? 'USSD system experiencing issues',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showHealthDetails(state.ussdHealth),
            child: const Text('Details', style: TextStyle(color: Colors.orange)),
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
          mainAxisSize:     MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status',        health?.status.toString().split('.').last ?? 'Unknown'),
            _buildDetailRow('Success Rate',  '${((health?.successRate ?? 0) * 100).toStringAsFixed(1)}%'),
            _buildDetailRow('Response Time', '${health?.responseTimeMs ?? 0}ms'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildUssdHealthIndicator(UssdHealthCheck? health) {
    Color   color;
    IconData icon;
    String  status;

    switch (health?.status) {
      case UssdStatus.green:
        color  = Colors.green;  icon = Icons.check_circle; status = 'Normal';   break;
      case UssdStatus.yellow:
        color  = Colors.orange; icon = Icons.warning;      status = 'Degraded'; break;
      case UssdStatus.red:
        color  = Colors.red;    icon = Icons.error;        status = 'Critical'; break;
      default:
        color  = Colors.grey;   icon = Icons.help;         status = 'Unknown';
    }

    return Column(
      children: [
        Container(
          padding:    const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child:      Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 5),
        Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tabs
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(DashboardState state, DashboardNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildQuickActions(),
        const SizedBox(height: 20),
        _buildRecentTransactions(state),
        const SizedBox(height: 20),
        _buildPopularProducts(state),
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
          const Text('Transactions Tab', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('View detailed transaction list', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/transaction-history'),
            style:     ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
            child:     const Text('View All Transactions'),
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
          const Text('Analytics Tab', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Advanced analytics coming soon', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Quick Actions grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap:        true,
          physics:           const NeverScrollableScrollPhysics(),
          crossAxisCount:    3,
          crossAxisSpacing:  10,
          mainAxisSpacing:   10,
          children: [
            _buildActionButton(icon: Icons.phone_android,          label: 'Airtime', color: Colors.green,  onTap: () => context.push('/airtime')),
            _buildActionButton(icon: Icons.wifi,                   label: 'Data',    color: Colors.blue,   onTap: () => context.push('/data')),
            _buildActionButton(icon: Icons.message,                label: 'SMS',     color: Colors.purple, onTap: () => context.push('/sms')),
            _buildActionButton(icon: Icons.account_balance_wallet, label: 'Top Up',  color: Colors.orange, onTap: () => context.push('/top-up')),
            _buildActionButton(icon: Icons.history,                label: 'History', color: Colors.teal,   onTap: () => context.push('/transaction-history')),
            _buildActionButton(icon: Icons.qr_code,                label: 'QR Pay',  color: Colors.red,    onTap: _showQRPaymentDialog),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:       40,
                height:      40,
                decoration:  BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child:       Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style:     const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRPaymentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:       200,
              height:      200,
              decoration:  BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              child:       const Center(
                child: Text('QR Code\nComing Soon', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code to accept payment from customers',
              textAlign: TextAlign.center,
              style:     TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recent transactions
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRecentTransactions(DashboardState state) {
    final transactions = state.recentTransactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push('/transaction-history'),
              child:     const Text('View All', style: TextStyle(color: Color(0xFF00C853))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            padding:    const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Column(children: [
              Icon(Icons.receipt_long, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text('No transactions yet', style: TextStyle(color: Colors.grey)),
            ]),
          )
        else
          ...transactions.map(_buildTransactionItem),
      ],
    );
  }

  Widget _buildTransactionItem(TransactionDetails transaction) {
    final isSuccess = transaction.status == TransactionStatus.success;
    final icon = transaction.type == TransactionType.airtime
        ? Icons.phone_android
        : transaction.type == TransactionType.data
            ? Icons.wifi
            : Icons.message;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width:       40,
          height:      40,
          decoration:  BoxDecoration(
            color:  (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
            shape:  BoxShape.circle,
          ),
          child: Icon(icon, color: isSuccess ? Colors.green : Colors.red),
        ),
        title: Text(
          transaction.type.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.customerPhone),
            Text(Formatters.formatDateTime(transaction.createdAt), style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment:  MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.formatCurrency(transaction.amount),
              style: TextStyle(fontWeight: FontWeight.bold, color: isSuccess ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 4),
            Container(
              padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                transaction.status.name,
                style: TextStyle(
                  fontSize:   10,
                  color:      isSuccess ? Colors.green : Colors.red,
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
            mainAxisSize:     MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Reference', transaction.safaricomReference ?? transaction.id),
              _buildDetailRow('Type',      transaction.type.name.toUpperCase()),
              _buildDetailRow('Amount',    Formatters.formatCurrency(transaction.amount)),
              _buildDetailRow('Customer',  transaction.customerPhone),
              _buildDetailRow('Status',    transaction.status.name.toUpperCase()),
              _buildDetailRow('Date',      Formatters.formatDateTime(transaction.createdAt)),
              if (transaction.completedAt != null)
                _buildDetailRow('Completed', Formatters.formatDateTime(transaction.completedAt!)),
              if (transaction.tokenAmount > 0)
                _buildDetailRow('Tokens',    transaction.tokenAmount.toString()),
              if (transaction.commission > 0)
                _buildDetailRow('Commission', Formatters.formatCurrency(transaction.commission)),
              if (transaction.balanceAfter != null)
                _buildDetailRow('Balance After', Formatters.formatCurrency(transaction.balanceAfter!)),
              if (transaction.errorMessage != null)
                _buildDetailRow('Error', transaction.errorMessage!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Close'),
          ),
          if (transaction.status == TransactionStatus.failed)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;

                // Show loading spinner
                BuildContext? loadCtx;
                showDialog(
                  context:            context,
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
                        ? (txState.retrySuccessMessage ?? 'Retried successfully')
                        : (txState.retryError           ?? 'Retry failed'),
                  ),
                  backgroundColor: success != null ? Colors.green : Colors.red,
                  duration:        const Duration(seconds: 3),
                ));

                if (success != null) {
                  await ref.read(dashboardNotifierProvider.notifier).refresh();
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
          child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Popular products
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPopularProducts(DashboardState state) {
    final products = state.popularProducts ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (products.isEmpty)
          Container(
            padding:    const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Column(children: [
              Icon(Icons.local_offer, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text('No products available', style: TextStyle(color: Colors.grey)),
            ]),
          )
        else
          Wrap(spacing: 10, runSpacing: 10, children: products.map(_buildProductChip).toList()),
      ],
    );
  }

  Widget _buildProductChip(ProductBundle product) {
    return ActionChip(
      avatar: Icon(
        product.type == TransactionType.airtime
            ? Icons.phone_android
            : product.type == TransactionType.data
                ? Icons.wifi
                : Icons.message,
        size:  16,
        color: Colors.white,
      ),
      label:           Text(
        '${product.value} - ${Formatters.formatCurrency(product.price)}',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF00C853),
      onPressed:       () => _showProductDetails(product),
    );
  }

  void _showProductDetails(ProductBundle product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize:     MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type',        product.type.name.toUpperCase()),
            _buildDetailRow('Value',       product.value),
            _buildDetailRow('Price',       Formatters.formatCurrency(product.price)),
            if (product.validityDays > 0)
              _buildDetailRow('Validity',  '${product.validityDays} days'),
            if (product.description.isNotEmpty)
              _buildDetailRow('Description', product.description),
            _buildDetailRow('USSD Code',  product.ussdCode),
            _buildDetailRow('Network',    product.network),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              switch (product.type) {
                case TransactionType.airtime: context.push('/airtime'); break;
                case TransactionType.data:    context.push('/data');    break;
                case TransactionType.sms:     context.push('/sms');     break;
                default:
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Purchase screen coming soon')),
                    );
                  }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Performance chart
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPerformanceChart(DashboardState state) {
    // Placeholder data — replace with real backend data in production
    final weekData = [12000.0, 15000.0, 8000.0, 22000.0, 18000.0, 25000.0, 20000.0];
    final days     = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding:    const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
                  DropdownMenuItem(value: 'WEEK',  child: Text('This Week')),
                  DropdownMenuItem(value: 'MONTH', child: Text('This Month')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref.read(dashboardNotifierProvider.notifier).changePeriod(v);
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
                  show:               true,
                  drawVerticalLine:   true,
                  horizontalInterval: 5000,
                  verticalInterval:   1,
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
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show:   true,
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
                    color:    const Color(0xFF00C853),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show:  true,
                      color: const Color(0xFF00C853).withOpacity(0.1),
                    ),
                    dotData: FlDotData(show: false),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom navigation
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex:         0,
      selectedItemColor:    const Color(0xFF00C853),
      unselectedItemColor:  Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard),              label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz),             label: 'Transactions'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.person),                 label: 'Profile'),
      ],
      onTap: (index) {
        switch (index) {
          case 1: context.push('/transaction-history'); break;
          case 2: context.push('/wallet');              break;
          case 3: context.push('/profile');             break;
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              AppLogger.logSessionEvent(event: 'Manual logout from dashboard');
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

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar delegate — pins the tab bar as the user scrolls down
// ─────────────────────────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController _tabController;
  _TabBarDelegate(this._tabController);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:           _tabController,
        indicatorColor:       const Color(0xFF00C853),
        labelColor:           const Color(0xFF00C853),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }

  @override double get maxExtent => 48;
  @override double get minExtent => 48;
  @override bool shouldRebuild(covariant SliverPersistentHeaderDelegate _) => true;
}