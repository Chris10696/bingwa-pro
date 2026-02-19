import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import 'package:bingwa_pro/shared/repositories/transaction_repository.dart';

class TransactionState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;
  String _currentFilter = 'all';
  String _currentPeriod = 'today';

  TransactionNotifier(this._repository) : super(TransactionState());

  Future<void> loadTransactions() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Create TransactionFilter based on current filter and period
      final filter = _createTransactionFilter(
        page: 1,
        filter: _currentFilter,
        period: _currentPeriod,
      );
      
      // Use getTransactionHistory instead of getTransactions
      final response = await _repository.getTransactionHistory(filter);
      
      // Convert TransactionDetails to Transaction using the extension method
      final transactions = response.transactions.map((details) => details.toTransaction()).toList();
      
      state = state.copyWith(
        transactions: transactions,
        isLoading: false,
        page: 1,
        hasMore: response.hasNextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load transactions: ${e.toString()}',
      );
    }
  }

  Future<void> loadMoreTransactions() async {
    if (state.isLoadingMore || !state.hasMore) return;

    try {
      state = state.copyWith(isLoadingMore: true);
      final nextPage = state.page + 1;
      
      // Create TransactionFilter for the next page
      final filter = _createTransactionFilter(
        page: nextPage,
        filter: _currentFilter,
        period: _currentPeriod,
      );
      
      // Use getTransactionHistory instead of getTransactions
      final response = await _repository.getTransactionHistory(filter);
      
      // Convert TransactionDetails to Transaction using the extension method
      final moreTransactions = response.transactions.map((details) => details.toTransaction()).toList();
      
      state = state.copyWith(
        transactions: [...state.transactions, ...moreTransactions],
        isLoadingMore: false,
        page: nextPage,
        hasMore: response.hasNextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more transactions: ${e.toString()}',
      );
    }
  }

  Future<void> refreshTransactions() async {
    await loadTransactions();
  }

  Future<void> filterByStatus(String status) async {
    _currentFilter = status;
    await loadTransactions();
  }

  Future<void> filterByPeriod(String period) async {
    _currentPeriod = period;
    await loadTransactions();
  }

  Future<void> retryTransaction(String transactionId) async {
    try {
      // TODO: Implement retry logic using _repository.retryTransaction()
      // You'll need to create a RetryRequest object
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to create TransactionFilter from filter string and period
  TransactionFilter _createTransactionFilter({
    required int page,
    required String filter,
    required String period,
  }) {
    // Map filter string to TransactionStatus
    List<TransactionStatus>? statuses;
    if (filter == 'success') {
      statuses = [TransactionStatus.success];
    } else if (filter == 'failed') {
      statuses = [TransactionStatus.failed, TransactionStatus.aborted];
    } else if (filter == 'pending') {
      statuses = [
        TransactionStatus.pending,
        TransactionStatus.initiated,
        TransactionStatus.validated,
        TransactionStatus.executing,
      ];
    }
    // 'all' will keep statuses as null

    // Map period to date range
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();
    
    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = now;
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case 'all':
      default:
        // No date filter for 'all'
        break;
    }
    
    return TransactionFilter(
      page: page,
      pageSize: 20,
      statuses: statuses,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repository = ref.read(transactionRepositoryProvider);
  return TransactionNotifier(repository);
});