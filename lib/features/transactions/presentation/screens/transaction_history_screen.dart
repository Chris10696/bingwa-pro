import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bingwa_pro/core/widgets/custom_app_bar.dart';
import 'package:bingwa_pro/core/widgets/loading_indicator.dart';
import 'package:bingwa_pro/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import 'package:go_router/go_router.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'all'; // all, success, failed, pending
  String _selectedPeriod = 'today'; // today, week, month

  @override
  void initState() {
    super.initState();
    // Load initial transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions();
    });
    
    // Setup infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        ref.read(transactionProvider.notifier).loadMoreTransactions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = ref.watch(transactionProvider);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Transaction History',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          
          // Transaction list or loading/error states
          Expanded(
            child: _buildTransactionList(transactionState),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week', 'week'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Month', 'month'),
                  const SizedBox(width: 8),
                  _buildFilterChip('All Time', 'all'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedPeriod == value,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
          ref.read(transactionProvider.notifier).filterByPeriod(value);
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: _selectedPeriod == value ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildTransactionList(TransactionState state) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: LoadingIndicator());
    }
    
    if (state.error != null) {
      return _buildErrorWidget(state.error!);
    }
    
    if (state.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.go('/airtime');
              },
              child: const Text('Make Your First Transaction'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(transactionProvider.notifier).refreshTransactions();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.transactions.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.transactions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          final transaction = state.transactions[index];
          return _buildTransactionItem(transaction);
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(transactionProvider.notifier).loadTransactions(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final statusName = transaction.status.name.toLowerCase();
    final typeName = transaction.type.name.toLowerCase();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getTransactionColor(statusName).withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              _getTransactionIcon(typeName),
              color: _getTransactionColor(statusName),
            ),
          ),
        ),
        title: Text(
          transaction.description ?? 'Transaction',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${transaction.recipientPhone} • ${_formatDate(transaction.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusName).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transaction.status.name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _getStatusColor(statusName),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'KSh ${transaction.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getAmountColor(transaction),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          _showTransactionDetails(transaction);
        },
      ),
    );
  }

  Color _getTransactionColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
      case 'initiated':
      case 'validated':
      case 'executing':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    return _getTransactionColor(status);
  }

  Color _getAmountColor(Transaction transaction) {
    // Assuming all transactions are debits for now
    return Colors.black;
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'airtime':
        return Icons.phone;
      case 'data':
        return Icons.wifi;
      case 'sms':
        return Icons.message;
      case 'bundle':
        return Icons.shopping_bag;
      case 'minutes':
        return Icons.call;
      default:
        return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);
    
    if (transactionDate == today) {
      return 'Today ${_formatTime(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Transactions'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('All Transactions'),
                    value: 'all',
                    groupValue: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Successful Only'),
                    value: 'success',
                    groupValue: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Failed Only'),
                    value: 'failed',
                    groupValue: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Pending Only'),
                    value: 'pending',
                    groupValue: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(transactionProvider.notifier).filterByStatus(_selectedFilter);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionDetails(Transaction transaction) {
    final statusName = transaction.status.name.toLowerCase();
    final typeName = transaction.type.name.toLowerCase();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getTransactionColor(statusName).withAlpha(25),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Icon(
                        _getTransactionIcon(typeName),
                        color: _getTransactionColor(statusName),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description ?? 'Transaction',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaction ID: ${transaction.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Amount', 'KSh ${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Type', transaction.type.name.toUpperCase()),
              _buildDetailRow('Recipient', transaction.recipientPhone),
              _buildDetailRow('Date', _formatDate(transaction.createdAt)),
              _buildDetailRow('Status', transaction.status.name.toUpperCase()),
              if (transaction.referenceId != null)
                _buildDetailRow('Reference', transaction.referenceId!),
              if (transaction.note != null)
                _buildDetailRow('Note', transaction.note!),
              const SizedBox(height: 24),
              if (statusName == 'failed')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement retry logic
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry Transaction'),
                  ),
                ),
              if (statusName == 'failed')
                const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTransactions() async {
    // TODO: Implement export to PDF/CSV
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}