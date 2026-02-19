import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/logger.dart';
import '../providers/dashboard_provider.dart';
// ========== ADD THESE IMPORT STATEMENTS ==========
import '../../../../shared/models/transaction_model.dart'; // For TransactionDetails, TransactionStatus, TransactionType
import '../../../../shared/models/agent_model.dart'; // For UssdStatus (actually in transaction_model, but we'll import it)
// UssdStatus and UssdHealthCheck are in transaction_model.dart
// ProductBundle is also in transaction_model.dart
// =================================================

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  bool _showScrollTopButton = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    
    // Load dashboard data
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
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    
    if (state.isLoading && state.agent == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading dashboard...'),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const GradientAppBar(
        title: 'Dashboard',
        actions: [
          // Will add notifications icon later
        ],
      ),
      drawer: _buildDrawer(state),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Top Stats Section
            SliverToBoxAdapter(
              child: _buildTopStats(state),
            ),
            // Health Warning (if any)
            if (state.showHealthWarning)
              SliverToBoxAdapter(
                child: _buildHealthWarning(state),
              ),
            // Tab Bar
            SliverPersistentHeader(
              delegate: _TabBarDelegate(_tabController),
              pinned: true,
            ),
            // Tab Views
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
      floatingActionButton: _buildFloatingActionButton(state, notifier),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
  
  Widget _buildDrawer(DashboardState state) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
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
                // FIXED: Changed ?. to . (can't be null due to short-circuiting)
                state.agent?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C853),
                ),
              ),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF00C853),
            ),
          ),
          // Menu Items
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xFF00C853)),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
            title: const Text('Wallet'),
            onTap: () {
              Navigator.pop(context);
              context.push('/wallet');
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer, color: Colors.orange),
            title: const Text('Offers'),
            onTap: () {
              // TODO: Navigate to offers
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.purple),
            title: const Text('Transaction History'),
            onTap: () {
              Navigator.pop(context);
              context.push('/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.teal),
            title: const Text('Customers'),
            onTap: () {
              // TODO: Navigate to customers
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.indigo),
            title: const Text('Reports'),
            onTap: () {
              // TODO: Navigate to reports
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help, color: Colors.grey),
            title: const Text('Help & Support'),
            onTap: () {
              // TODO: Navigate to help
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () {
              _confirmLogout(context);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopStats(DashboardState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            // FIXED: Changed withOpacity to withAlpha for better precision
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
          // Welcome Message
          Text(
            'Welcome back, ${state.agent?.fullName.split(' ').first ?? 'Agent'}!',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          // Token Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Token Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.formatCurrency(state.walletBalance?.availableBalance ?? 0),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C853),
                    ),
                  ),
                ],
              ),
              // USSD Health Indicator
              _buildUssdHealthIndicator(state.ussdHealth),
            ],
          ),
          const SizedBox(height: 20),
          // Quick Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Today Sales',
                  value: Formatters.formatCurrency(state.stats?.todaySales ?? 0),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'Success Rate',
                  value: '${((state.stats?.successRate ?? 0) * 100).toStringAsFixed(1)}%',
                  icon: Icons.check_circle,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'Commission',
                  value: Formatters.formatCurrency(state.stats?.todayCommission ?? 0),
                  icon: Icons.attach_money,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHealthWarning(DashboardState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        // FIXED: Changed withOpacity to withAlpha
        color: const Color.fromARGB(255, 255, 244, 229), // Colors.orange[50] equivalent
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromARGB(255, 255, 204, 128)), // Colors.orange[100] equivalent
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
                  state.ussdHealth?.message ?? 'USSD system experiencing issues',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Show details
            },
            child: const Text(
              'Details',
              style: TextStyle(color: Colors.orange),
            ),
          ),
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
          // FIXED: Use .withOpacity() directly since it's a double parameter, not Color
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
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
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      // FIXED: Use .withOpacity() directly since it's a double parameter
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
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
  
  Widget _buildOverviewTab(DashboardState state, DashboardNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        // Quick Actions
        _buildQuickActions(),
        const SizedBox(height: 20),
        // Recent Transactions
        _buildRecentTransactions(state),
        const SizedBox(height: 20),
        // Popular Products
        _buildPopularProducts(state),
        const SizedBox(height: 20),
        // Performance Chart
        _buildPerformanceChart(state),
      ],
    );
  }
  
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildActionButton(
              icon: Icons.phone_android,
              label: 'Airtime',
              color: Colors.green,
              onTap: () => context.push('/transactions/airtime'),
            ),
            _buildActionButton(
              icon: Icons.wifi,
              label: 'Data',
              color: Colors.blue,
              onTap: () => context.push('/transactions/data'),
            ),
            _buildActionButton(
              icon: Icons.message,
              label: 'SMS',
              color: Colors.purple,
              onTap: () => context.push('/transactions/sms'),
            ),
            _buildActionButton(
              icon: Icons.account_balance_wallet,
              label: 'Top Up',
              color: Colors.orange,
              onTap: () => context.push('/wallet/topup'),
            ),
            _buildActionButton(
              icon: Icons.history,
              label: 'History',
              color: Colors.teal,
              onTap: () => context.push('/history'),
            ),
            _buildActionButton(
              icon: Icons.qr_code,
              label: 'QR Pay',
              color: Colors.red,
              onTap: () {
                // TODO: QR payment
              },
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                // FIXED: Use .withOpacity() directly
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/history'),
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
            child: const Column(
              children: [
                Icon(Icons.receipt_long, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No transactions yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...transactions.map((transaction) => _buildTransactionItem(transaction)),
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
          width: 40,
          height: 40,
          // FIXED: Use .withOpacity() directly
          decoration: BoxDecoration(
            color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSuccess ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          // FIXED: Changed .name to .name (enum property)
          transaction.type.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.customerPhone),
            Text(
              Formatters.formatDateTime(transaction.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              // FIXED: Use .withOpacity() directly
              decoration: BoxDecoration(
                color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                // FIXED: Changed .name to .name (enum property)
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
      ),
    );
  }
  
  Widget _buildPopularProducts(DashboardState state) {
    final products = state.popularProducts ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Products',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(Icons.local_offer, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No products available',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: products.map((product) => _buildProductChip(product)).toList(),
          ),
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
        size: 16,
        color: Colors.white,
      ),
      label: Text(
        '${product.value} - ${Formatters.formatCurrency(product.price)}',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF00C853),
      onPressed: () {
        // TODO: Navigate to product details
      },
    );
  }
  
  Widget _buildPerformanceChart(DashboardState state) {
    // Mock data for chart
    final weekData = [12000.0, 15000.0, 8000.0, 22000.0, 18000.0, 25000.0, 20000.0];
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: weekData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF00C853),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      // FIXED: Use .withOpacity() directly
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
  
  Widget _buildTransactionsTab(DashboardState state) {
    return const Center(
      child: Text('Transactions Tab - Coming Soon'),
    );
  }
  
  Widget _buildAnalyticsTab(DashboardState state) {
    return const Center(
      child: Text('Analytics Tab - Coming Soon'),
    );
  }
  
  Widget _buildFloatingActionButton(DashboardState state, DashboardNotifier notifier) {
    if (state.isProcessing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () => notifier.pauseProcessing(),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.pause),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => notifier.stopProcessing(),
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          ),
        ],
      );
    }
    
    return FloatingActionButton(
      onPressed: () => notifier.startProcessing(),
      backgroundColor: const Color(0xFF00C853),
      child: const Icon(Icons.play_arrow),
    );
  }
  
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: const Color(0xFF00C853),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Wallet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            // Already on dashboard
            break;
          case 1:
            context.push('/history');
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
  
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              AppLogger.logSessionEvent(event: 'Manual logout from dashboard');
              context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// Tab Bar Delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController _tabController;
  
  _TabBarDelegate(this._tabController);
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}