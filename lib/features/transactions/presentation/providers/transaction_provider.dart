// lib/features/transactions/presentation/providers/transaction_provider.dart
// W1 edits per primer entity renames:
//   - retryTransaction(): productName/bundleSize → offerName, bundleSize dropped
//   - recordTransaction(): productId/productName → offerId/offerName per Q1
//     (keep with rename only; scaffolding values preserved with TODO markers)
// All other methods preserved verbatim.
import 'package:bingwa_nexus/core/utils/logger.dart';
import 'package:bingwa_nexus/shared/models/transaction_model.dart';
import 'package:bingwa_nexus/shared/repositories/transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
      final filter = _createTransactionFilter(
        page: 1,
        filter: _currentFilter,
        period: _currentPeriod,
      );
      final response = await _repository.getTransactionHistory(filter);
      final transactions =
          response.transactions.map((details) => details.toTransaction()).toList();
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
      final filter = _createTransactionFilter(
        page: nextPage,
        filter: _currentFilter,
        period: _currentPeriod,
      );
      final response = await _repository.getTransactionHistory(filter);
      final moreTransactions =
          response.transactions.map((details) => details.toTransaction()).toList();
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

  Future<String> _getDeviceId() async {
    try {
      final deviceId = await DeviceFingerprint.generateDeviceId();
      if (deviceId.isNotEmpty) {
        return deviceId;
      }
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<TransactionResponse?> retryTransaction(String transactionId) async {
    state = state.copyWith(
        isRetrying: true, retryError: null, retrySuccessMessage: null);
    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }
      final deviceId = await _getDeviceId();
      final request = RetryRequest(
        transactionId: transactionId,
        agentId: agentId,
        deviceId: deviceId,
        newUssdCode: null,
        overrideParams: null,
      );

      final response = await _repository.retryTransaction(request);

      // W1: productName → offerName; bundleSize dropped.
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
            offerName: t.offerName,
            subscriptionPlanId: t.subscriptionPlanId,
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

  /// Q1 default: keep with field renames only.
  /// This method has hardcoded scaffolding values (type, offerName) that
  /// should be replaced by W2 when the offer-execution flow is wired in.
  Future<TransactionDetails> recordTransaction({
    required String customerPhone,
    required double amount,
    required String offerId, // renamed from productId
    required String reference,
  }) async {
    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }
      // TODO(wave-2): replace hardcoded type/offerName/commission/tokenAmount
      //   with real values from the offer-execution flow. W1 keeps the
      //   scaffolding so the method signature stays callable.
      final transaction = TransactionDetails(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        agentId: agentId,
        customerPhone: customerPhone,
        amount: amount,
        type: TransactionType.quickDial, // TODO(wave-2): from offer.category
        status: TransactionStatus.success,
        offerId: offerId,
        offerName: 'Subscription Offer', // TODO(wave-2): from offer.name
        reference: reference,
        safaricomReference: reference,
        tokenAmount: 1,
        commission: amount * 0.05, // TODO(wave-2): from commission service (W5)
        balanceAfter: 0,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      final newTransaction = transaction.toTransaction();
      final updatedTransactions = [newTransaction, ...state.transactions];

      state = state.copyWith(
        transactions: updatedTransactions.take(50).toList(),
      );

      AppLogger.logTransaction(
        type: 'Record',
        phone: customerPhone,
        amount: amount,
        status: 'SUCCESS',
        reference: reference,
      );
      return transaction;
    } catch (e) {
      AppLogger.e('Failed to record transaction:', e);
      rethrow;
    }
  }

  void clearRetryMessages() {
    state = state.copyWith(
      retryError: null,
      retrySuccessMessage: null,
    );
  }

  TransactionFilter _createTransactionFilter({
    required int page,
    required String filter,
    required String period,
  }) {
    List<TransactionStatus>? statuses;
    if (filter == 'success') {
      statuses = [TransactionStatus.success];
    } else if (filter == 'failed') {
      statuses = [
        TransactionStatus.failed,
        TransactionStatus.failedAlreadyRecommended,
        TransactionStatus.failedOfferDeactivated,
        TransactionStatus.blocked,
      ];
    } else if (filter == 'pending') {
      statuses = [
        TransactionStatus.scheduled,
        TransactionStatus.processing,
        TransactionStatus.rescheduled,
        TransactionStatus.paused,
      ];
    }
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

  Transaction? getTransactionById(String id) {
    try {
      return state.transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repository = ref.read(transactionRepositoryProvider);
  return TransactionNotifier(repository, ref);
});