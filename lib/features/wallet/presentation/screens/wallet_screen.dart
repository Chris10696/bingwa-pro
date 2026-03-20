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
  bool _showTokenPackages = false;

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

    // Show success messages
    if (state.transferSuccess != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.transferSuccess!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        notifier.clearError();
      });
    }

    if (state.withdrawalSuccess != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.withdrawalSuccess!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        notifier.clearError();
      });
    }

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

                  // Token Stats Card
                  _buildTokenStatsCard(state),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(state),
                  const SizedBox(height: 20),

                  // Token Packages Section (collapsible)
                  _buildTokenPackagesSection(state),
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
                            context.push('/transaction-history');
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/wallet/topup');
        },
        backgroundColor: const Color(0xFF00C853),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Buy Tokens', style: TextStyle(color: Colors.white)),
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
            color: Colors.green.withValues(alpha: 0.3),
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

  Widget _buildTokenStatsCard(WalletState state) {
    // Safe access to token fields with null checks
    final tokenBalance = state.balance?.tokenBalanceInt ?? 0;
    final lifetimeTokens = state.balance?.lifetimeTokens ?? 0;
    final tokensConsumed = state.balance?.tokensConsumed ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
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
                  const SizedBox(height: 4),
                  Text(
                    '$tokenBalance',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C853),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.token,
                  color: Color(0xFF00C853),
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$lifetimeTokens',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Lifetime',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$tokensConsumed',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Consumed',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${((tokensConsumed / (lifetimeTokens == 0 ? 1 : lifetimeTokens)) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Usage Rate',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: lifetimeTokens == 0 ? 0 : tokensConsumed / lifetimeTokens,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenPackagesSection(WalletState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Token Packages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(
                  _showTokenPackages ? Icons.expand_less : Icons.expand_more,
                ),
                onPressed: () {
                  setState(() {
                    _showTokenPackages = !_showTokenPackages;
                  });
                },
              ),
            ],
          ),
        ),
        if (_showTokenPackages)
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4, // Mock data - replace with actual token packages
              itemBuilder: (context, index) {
                return _buildTokenPackageCard(index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTokenPackageCard(int index) {
    // Mock data - replace with actual data from provider
    final packages = [
      {'name': 'Daily Trial', 'tokens': 50, 'price': 20, 'color': Colors.blue},
      {'name': 'Weekly Starter', 'tokens': 500, 'price': 150, 'color': Colors.purple},
      {'name': 'Monthly Business', 'tokens': 2500, 'price': 500, 'color': Colors.orange},
      {'name': 'Bulk Trader', 'tokens': 10000, 'price': 1500, 'color': Colors.red},
    ];

    final package = packages[index];

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (package['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.token,
                  color: package['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                package['name'] as String,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${package['tokens']} tokens',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KES ${package['price']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C853),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Navigate to topup with selected package
                      context.push('/wallet/topup');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Buy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(WalletState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.add,
            label: 'Top Up',
            isLoading: state.isPurchasingTokens,
            onTap: () {
              context.push('/wallet/topup');
            },
          ),
          _buildActionButton(
            icon: Icons.history,
            label: 'History',
            isLoading: false,
            onTap: () {
              context.push('/transaction-history');
            },
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Transfer',
            isLoading: state.isTransferring,
            onTap: () {
              _showTransferDialog(state);
            },
          ),
          _buildActionButton(
            icon: Icons.download,
            label: 'Withdraw',
            isLoading: state.isWithdrawing,
            onTap: () {
              _showWithdrawalDialog(state);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00C853),
                  ),
                )
              : IconButton(
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

  void _showTransferDialog(WalletState state) {
    final amountController = TextEditingController();
    final agentIdController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transfer Tokens'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: agentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Agent ID',
                    hintText: 'Enter agent ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient agent ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (Tokens)',
                    hintText: 'Enter token amount',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = int.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (state.balance?.tokenBalanceInt != null && 
                        amount > state.balance!.tokenBalanceInt) {
                      return 'Insufficient tokens';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              Navigator.pop(dialogContext);
              
              final amount = int.parse(amountController.text);
              await ref.read(walletNotifierProvider.notifier).transferTokens(
                toAgentId: agentIdController.text,
                amount: amount.toDouble(),
                description: descriptionController.text.isNotEmpty 
                    ? descriptionController.text 
                    : 'Token transfer',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalDialog(WalletState state) {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedMethod = 'MPESA_TILL';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Withdraw Tokens'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '07XX XXX XXX',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (!RegExp(r'^07\d{8}$').hasMatch(value)) {
                          return 'Enter a valid Safaricom number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MPESA_TILL',
                          child: Text('M-Pesa Till Number'),
                        ),
                        DropdownMenuItem(
                          value: 'MPESA_PAYBILL',
                          child: Text('M-Pesa PayBill'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedMethod = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (Tokens)',
                        hintText: 'Enter token amount',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = int.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        if (state.balance?.tokenBalanceInt != null && 
                            amount > state.balance!.tokenBalanceInt) {
                          return 'Insufficient tokens';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  Navigator.pop(dialogContext);
                  
                  final amount = int.parse(amountController.text);
                  await ref.read(walletNotifierProvider.notifier).withdrawTokens(
                    amount: amount.toDouble(),
                    phoneNumber: phoneController.text,
                    paymentMethod: selectedMethod,
                    description: 'Token withdrawal',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                child: const Text('Withdraw'),
              ),
            ],
          );
        },
      ),
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
            color: color.withValues(alpha: 0.1),
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
            if (transaction.recipientAgentId != null)
              Text('To: ${transaction.recipientAgentId}', style: const TextStyle(fontSize: 10)),
            if (transaction.recipientPhone != null)
              Text('To: ${transaction.recipientPhone}', style: const TextStyle(fontSize: 10)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${transaction.amount > 0 ? '+' : ''}${transaction.amount} tokens',
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