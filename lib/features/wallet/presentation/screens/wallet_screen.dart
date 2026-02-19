import 'package:bingwa_pro/shared/models/wallet_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletNotifierProvider.notifier).loadWalletData();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(walletNotifierProvider.notifier).loadMoreTransactions();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletNotifierProvider);
    final notifier = ref.read(walletNotifierProvider.notifier);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Wallet',
        showBackButton: true,
      ),
      body: state.isLoading && state.balance == null
          ? const LoadingIndicator(message: 'Loading wallet...')
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: ListView(
                controller: _scrollController,
                children: [
                  // Balance Card
                  _buildBalanceCard(state),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 20),

                  // Transactions Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
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
                          onPressed: () {
                            // TODO: Navigate to full transaction history
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(color: Color(0xFF00C853)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transactions List
                  _buildTransactionsList(state),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/wallet/topup');
        },
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBalanceCard(WalletState state) {
    final balance = state.balance?.availableBalance ?? 0.0;
    final pending = state.balance?.pendingBalance ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF64DD17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.formatCurrency(balance),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(pending),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Deposits',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(state.balance?.totalDeposits ?? 0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.add,
            label: 'Top Up',
            onTap: () {
              context.push('/wallet/topup');
            },
          ),
          _buildActionButton(
            icon: Icons.history,
            label: 'History',
            onTap: () {
              // TODO: Navigate to full history
            },
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Transfer',
            onTap: () {
              // TODO: Implement transfer
            },
          ),
          _buildActionButton(
            icon: Icons.download,
            label: 'Withdraw',
            onTap: () {
              // TODO: Implement withdrawal
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFF00C853)),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(WalletState state) {
    final transactions = state.transactions ?? [];

    if (transactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            const Icon(Icons.receipt_long, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No transactions yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                context.push('/wallet/topup');
              },
              child: const Text('Make your first top-up'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == transactions.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transaction = transactions[index];
        return _buildTransactionItem(transaction);
      },
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    final isSuccess = transaction.status == WalletTransactionStatus.success;
    final isPending = transaction.status == WalletTransactionStatus.pending;
    final isFailed = transaction.status == WalletTransactionStatus.failed;

    Color color;
    IconData icon;

    if (isSuccess) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (isPending) {
      color = Colors.orange;
      icon = Icons.pending;
    } else {
      color = Colors.red;
      icon = Icons.error;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          transaction.type.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.reference),
            Text(
              DateFormat('dd MMM, HH:mm').format(transaction.timestamp),
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
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transaction.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}