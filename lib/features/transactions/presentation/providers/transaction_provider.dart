import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import 'package:bingwa_pro/shared/repositories/transaction_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/device_fingerprint.dart';

class TransactionState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final bool isRetrying;
  final String? retryError;
  final String? retrySuccessMessage;

  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.isRetrying = false,
    this.retryError,
    this.retrySuccessMessage,
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    bool? isRetrying,
    String? retryError,
    String? retrySuccessMessage,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isRetrying: isRetrying ?? this.isRetrying,
      retryError: retryError ?? this.retryError,
      retrySuccessMessage: retrySuccessMessage ?? this.retrySuccessMessage,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;
  final Ref _ref;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  String _currentFilter = 'all';
  String _currentPeriod = 'today';

  TransactionNotifier(this._repository, this._ref) : super(TransactionState());

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

  // Helper method to get device ID
  Future<String> _getDeviceId() async {
    try {
      // First try to get from DeviceFingerprint
      final deviceId = await DeviceFingerprint.generateDeviceId();
      if (deviceId.isNotEmpty) {
        return deviceId;
      }
      
      // Fallback to device info
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      // Last resort fallback
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // FIXED: Implement retry logic (Line 129)
  Future<TransactionResponse?> retryTransaction(String transactionId) async {
    state = state.copyWith(isRetrying: true, retryError: null, retrySuccessMessage: null);

    try {
      // Get agent ID from auth state
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      
      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }

      // Get device ID
      final deviceId = await _getDeviceId();

      // Create retry request
      final request = RetryRequest(
        transactionId: transactionId,
        agentId: agentId,
        deviceId: deviceId,
        newUssdCode: null, // Use original USSD code
        overrideParams: null,
      );

      // Execute retry
      final response = await _repository.retryTransaction(request);

      // Update the transaction in the list
      final updatedTransactions = state.transactions.map((t) {
        if (t.id == transactionId) {
          return Transaction(
            id: response.transactionId,
            type: t.type,
            amount: response.amount,
            recipientPhone: t.recipientPhone,
            status: response.status,
            createdAt: t.createdAt,
            updatedAt: DateTime.now(),
            referenceId: response.reference,
            description: t.description,
            commission: response.commission,
            agentId: t.agentId,
            productName: t.productName,
            bundleSize: t.bundleSize,
            balanceAfter: response.balanceAfter,
          );
        }
        return t;
      }).toList();

      state = state.copyWith(
        transactions: updatedTransactions,
        isRetrying: false,
        retrySuccessMessage: 'Transaction retried successfully',
      );

      return response;
    } catch (e) {
      state = state.copyWith(
        isRetrying: false,
        retryError: 'Retry failed: ${e.toString()}',
      );
      return null;
    }
  }

  // Clear retry messages
  void clearRetryMessages() {
    state = state.copyWith(
      retryError: null,
      retrySuccessMessage: null,
    );
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

  // Get transaction by ID
  Transaction? getTransactionById(String id) {
    try {
      return state.transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repository = ref.read(transactionRepositoryProvider);
  return TransactionNotifier(repository, ref);
});