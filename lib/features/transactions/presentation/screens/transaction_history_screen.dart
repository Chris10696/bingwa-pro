import 'package:bingwa_nexus/core/widgets/custom_app_bar.dart';
import 'package:bingwa_nexus/core/widgets/loading_indicator.dart';
import 'package:bingwa_nexus/core/services/session_bridge_service.dart';
import 'package:bingwa_nexus/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:bingwa_nexus/shared/models/transaction_model.dart';
import 'package:bingwa_nexus/shared/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  // Status row: live, all, success, failed, pending. Period row: today, yesterday, last7, last30.
  String _selectedFilter = 'live';
  String _selectedPeriod = 'last7';

  // Search (Hybrid searchTransaction).
  bool _searchMode = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-select (Hybrid selection mode: Select All / Retry / Delete).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _retrying = false;

  // Soft-delete: Hybrid sets deletedAt and hides the row. Pro has no delete endpoint, so we
  // hide locally (the backend money/audit record is never destroyed — matches the soft-delete
  // intent). Persisted so hidden transactions stay hidden across launches.
  static const _hiddenKey = 'hidden_transaction_ids';
  Set<String> _hiddenIds = {};

  @override
  void initState() {
    super.initState();
    _loadHidden();
    // Apply the default status + period to the provider, then load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(transactionProvider.notifier);
      notifier.filterByStatus(_selectedFilter);
      notifier.filterByPeriod(_selectedPeriod);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHidden() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hiddenIds = (prefs.getStringList(_hiddenKey) ?? []).toSet());
  }

  // Visible = not soft-deleted, matching the active search query.
  List<Transaction> _visible(TransactionState state) {
    Iterable<Transaction> list =
        state.transactions.where((t) => !_hiddenIds.contains(t.id));
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery;
      list = list.where((t) =>
          t.recipientPhone.toLowerCase().contains(q) ||
          (t.description ?? '').toLowerCase().contains(q) ||
          (t.offerName ?? '').toLowerCase().contains(q) ||
          (t.referenceId ?? '').toLowerCase().contains(q));
    }
    return list.toList();
  }

  bool _isFailed(TransactionStatus s) =>
      s == TransactionStatus.failed ||
      s == TransactionStatus.failedAlreadyRecommended ||
      s == TransactionStatus.failedOfferDeactivated ||
      s == TransactionStatus.blocked;

  // ── selection / search mode controls ──────────────────────────────────────
  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });

  void _exitSearch() {
    _searchController.clear();
    setState(() {
      _searchMode = false;
      _searchQuery = '';
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelection(String id) => setState(() {
        _selectionMode = true;
        _selectedIds.add(id);
      });

  void _selectAllVisible() {
    final ids = _visible(ref.read(transactionProvider)).map((t) => t.id);
    setState(() => _selectedIds.addAll(ids));
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove transactions?'),
        content: Text(
            'Hide $count transaction(s) from your history. Your records are kept; '
            'this only removes them from this list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hiddenIds.addAll(_selectedIds);
      _selectionMode = false;
      _selectedIds.clear();
    });
    await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
  }

  // Re-queue selected FAILED transactions through the native dial pipeline (money-safe:
  // only FAILED rows with a ussdCode are re-dialed; the W3 pipeline dials each at most once).
  Future<void> _retrySelected() async {
    final selectedFailed = _visible(ref.read(transactionProvider))
        .where((t) => _selectedIds.contains(t.id) && _isFailed(t.status))
        .toList();
    if (selectedFailed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only failed transactions can be retried')),
      );
      return;
    }
    setState(() => _retrying = true);
    final repo = ref.read(transactionRepositoryProvider);
    final bridge = ref.read(sessionBridgeServiceProvider);
    var queued = 0;
    for (final t in selectedFailed) {
      try {
        final d = await repo.getTransactionDetails(t.id);
        final code = d.ussdCode;
        if (code != null && code.isNotEmpty) {
          await bridge.enqueueQuickDial(
            transactionId: d.id,
            ussdCode: code,
            customerPhone: d.customerPhone,
            offerId: d.offerId,
            offerName: d.offerName,
            amount: d.amount.toInt(),
            offerPrice: d.amount.toInt(),
          );
          queued++;
        }
      } catch (_) {
        // skip this one; continue with the rest
      }
    }
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _selectionMode = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Re-queued $queued transaction(s) for dialing')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = ref.watch(transactionProvider);
    
    return Scaffold(
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: _exitSelection),
        title: Text('${_selectedIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: _selectAllVisible,
          ),
          IconButton(
            icon: _retrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Retry',
            onPressed: _retrying ? null : _retrySelected,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    if (_searchMode) {
      return AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: _exitSearch),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by phone, offer, reference…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      );
    }
    return CustomAppBar(
      title: 'Transaction History',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searchMode = true),
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _exportTransactions,
        ),
      ],
    );
  }

  // Two filter rows matching Hybrid: status (Live/All/Successful/Failed/Pending)
  // then period (Today/Yesterday/Last 7 days/Last 30 days). FilterChip shows a
  // checkmark on the selected chip, like Hybrid.
  Widget _buildFilterChips() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildStatusChip('Live', 'live'),
              const SizedBox(width: 8),
              _buildStatusChip('All', 'all'),
              const SizedBox(width: 8),
              _buildStatusChip('Successful', 'success'),
              const SizedBox(width: 8),
              _buildStatusChip('Failed', 'failed'),
              const SizedBox(width: 8),
              _buildStatusChip('Pending', 'pending'),
            ],
          ),
        ),
        const Divider(height: 1),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildPeriodChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildPeriodChip('Yesterday', 'yesterday'),
              const SizedBox(width: 8),
              _buildPeriodChip('Last 7 days', 'last7'),
              const SizedBox(width: 8),
              _buildPeriodChip('Last 30 days', 'last30'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final selected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
        ref.read(transactionProvider.notifier).filterByStatus(value);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF00C853),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final selected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedPeriod = value);
        ref.read(transactionProvider.notifier).filterByPeriod(value);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF00C853),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
    );
  }

  Widget _buildTransactionList(TransactionState state) {
    if (state.isLoading && state.transactions.isEmpty) {
      return const Center(child: LoadingIndicator());
    }
    
    if (state.error != null) {
      return _buildErrorWidget(state.error!);
    }
    
    final visible = _visible(state);
    if (visible.isEmpty) {
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
                context.go('/quick-dial'); // W2 fix: was /airtime (removed in W1)
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
        itemCount: visible.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visible.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final transaction = visible[index];
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
    final selected = _selectedIds.contains(transaction.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color:
          selected ? const Color(0xFF00C853).withValues(alpha: 0.12) : null,
      child: ListTile(
        leading: _selectionMode
            ? Checkbox(
                value: selected,
                activeColor: const Color(0xFF00C853),
                onChanged: (_) => _toggleSelect(transaction.id),
              )
            : Container(
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
        trailing: _selectionMode
            ? null
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          if (_selectionMode) {
            _toggleSelect(transaction.id);
          } else {
            _showTransactionDetails(transaction);
          }
        },
        onLongPress: () => _enterSelection(transaction.id),
      ),
    );
  }

  Color _getTransactionColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
      case 'failedalreadyrecommended':
      case 'failedofferdeactivated':
      case 'blocked':
        return Colors.red;
      case 'scheduled':
      case 'processing':
      case 'rescheduled':
      case 'paused':
        return Colors.orange;
      case 'unmatched':
        return Colors.grey;
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
      case 'quickdial':
        return Icons.phone_forwarded;
      case 'mpesa':
        return Icons.payments;
      case 'till':
        return Icons.point_of_sale;
      case 'sitelink':
        return Icons.link;
      case 'subscriptionrenewal':
        return Icons.autorenew;
      case 'airtimebalancecheck':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    // Backend timestamps are UTC; convert to local (EAT) before bucketing/formatting,
    // else both the Today/Yesterday split and _formatTime (raw .hour/.minute) read UTC.
    date = date.toLocal();
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