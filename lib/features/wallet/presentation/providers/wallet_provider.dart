// lib/features/wallet/presentation/providers/wallet_provider.dart
import 'package:bingwa_pro/core/utils/formatters.dart';
import 'package:bingwa_pro/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/repositories/wallet_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/secure_storage_manager.dart';

part 'wallet_provider.freezed.dart';

@freezed
abstract class WalletState with _$WalletState {
  const factory WalletState({
    @Default(false) bool isLoading,
    WalletBalance? balance,
    List<WalletTransaction>? transactions,
    @Default(1) int currentPage,
    @Default(false) bool hasMore,
    String? errorMessage,
    @Default(false) bool isPurchasingTokens,
    @Default(false) bool isConfirmingPayment,
    @Default(false) bool isTransferring,
    @Default(false) bool isWithdrawing,
    WalletTransaction? pendingTransaction,
    List<PaymentMethod>? paymentMethods,
    @Default('MPESA') String selectedPaymentMethod,
    String? transferSuccess,
    String? withdrawalSuccess,
  }) = _WalletState;
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _walletRepository;
  final Ref _ref;

  WalletNotifier(this._walletRepository, this._ref) : super(const WalletState());

  Future<void> loadWalletData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final balance = await _walletRepository.getWalletBalance();
      final transactions = await _walletRepository.getWalletTransactions(limit: 10);
      final paymentMethods = await _walletRepository.getPaymentMethods();

      state = state.copyWith(
        isLoading: false,
        balance: balance,
        transactions: transactions,
        paymentMethods: paymentMethods,
        hasMore: transactions.length >= 10,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load wallet data: ${e.toString()}',
      );
    }
  }

  Future<void> loadMoreTransactions() async {
    if (state.isLoading || !state.hasMore) return;

    final nextPage = state.currentPage + 1;

    state = state.copyWith(isLoading: true);

    try {
      final moreTransactions = await _walletRepository.getWalletTransactions(
        limit: 10,
        offset: nextPage * 10,
      );

      final existingTransactions = state.transactions ?? <WalletTransaction>[];
      
      final List<WalletTransaction> allTransactions = [
        ...existingTransactions,
        ...moreTransactions,
      ];

      state = state.copyWith(
        isLoading: false,
        transactions: allTransactions,
        currentPage: nextPage,
        hasMore: moreTransactions.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load more transactions: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1);
    await loadWalletData();
  }

  Future<void> purchaseTokens({
    required double amount,
    required String paymentMethod,
    String? tillNumber,
    String? paybillNumber,
    String? accountNumber,
    String? phoneNumber,
  }) async {
    if (state.isPurchasingTokens) return;

    state = state.copyWith(isPurchasingTokens: true, errorMessage: null);

    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      
      final deviceId = await SecureStorageManager.getDeviceId() ?? '';

      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }

      final request = TokenPurchaseRequest(
        agentId: agentId,
        amount: amount,
        paymentMethod: paymentMethod,
        tillNumber: tillNumber,
        paybillNumber: paybillNumber,
        accountNumber: accountNumber,
        phoneNumber: phoneNumber,
        deviceId: deviceId,
      );

      final transaction = await _walletRepository.purchaseTokens(request);

      final newBalance = state.balance?.copyWith(
        availableBalance: (state.balance?.availableBalance ?? 0) + amount,
        totalBalance: (state.balance?.totalBalance ?? 0) + amount,
        lastUpdated: DateTime.now(),
      );

      final existingTransactions = state.transactions ?? <WalletTransaction>[];
      
      state = state.copyWith(
        isPurchasingTokens: false,
        balance: newBalance,
        transactions: [transaction, ...existingTransactions],
        pendingTransaction: transaction.status == WalletTransactionStatus.pending ? transaction : null,
      );
    } catch (e) {
      state = state.copyWith(
        isPurchasingTokens: false,
        errorMessage: 'Failed to purchase tokens: ${e.toString()}',
      );
    }
  }

  // Transfer tokens to another agent
  Future<void> transferTokens({
    required String toAgentId,
    required double amount,
    required String description,
  }) async {
    if (state.isTransferring) return;

    state = state.copyWith(isTransferring: true, errorMessage: null, transferSuccess: null);

    try {
      final authState = _ref.read(authNotifierProvider);
      final fromAgentId = authState.agent?.id ?? '';
      
      final deviceId = await SecureStorageManager.getDeviceId() ?? '';

      if (fromAgentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }

      if (fromAgentId == toAgentId) {
        throw Exception('Cannot transfer to yourself');
      }

      if (state.balance?.availableBalance == null || state.balance!.availableBalance < amount) {
        throw Exception('Insufficient balance for transfer');
      }

      final request = TransferRequest(
        fromAgentId: fromAgentId,
        toAgentId: toAgentId,
        amount: amount,
        description: description,
        deviceId: deviceId,
      );

      final transaction = await _walletRepository.transferTokens(request);

      final newBalance = await _walletRepository.getWalletBalance();
      
      final existingTransactions = state.transactions ?? <WalletTransaction>[];
      
      state = state.copyWith(
        isTransferring: false,
        balance: newBalance,
        transactions: [transaction, ...existingTransactions],
        transferSuccess: 'Successfully transferred ${Formatters.formatCurrency(amount)}',
      );
    } catch (e) {
      state = state.copyWith(
        isTransferring: false,
        errorMessage: 'Transfer failed: ${e.toString()}',
      );
    }
  }

  // Withdraw tokens to M-Pesa
  Future<void> withdrawTokens({
    required double amount,
    required String phoneNumber,
    required String paymentMethod,
    String? tillNumber,
    String? paybillNumber,
    String? accountNumber,
    String? description,
  }) async {
    if (state.isWithdrawing) return;

    state = state.copyWith(isWithdrawing: true, errorMessage: null, withdrawalSuccess: null);

    try {
      final authState = _ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      
      final deviceId = await SecureStorageManager.getDeviceId() ?? '';

      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }

      if (state.balance?.availableBalance == null || state.balance!.availableBalance < amount) {
        throw Exception('Insufficient balance for withdrawal');
      }

      final request = WithdrawalRequest(
        agentId: agentId,
        amount: amount,
        phoneNumber: phoneNumber,
        paymentMethod: paymentMethod,
        deviceId: deviceId,
        tillNumber: tillNumber,
        paybillNumber: paybillNumber,
        accountNumber: accountNumber,
        description: description ?? 'Token withdrawal',
      );

      final transaction = await _walletRepository.withdrawTokens(request);

      final newBalance = await _walletRepository.getWalletBalance();
      
      final existingTransactions = state.transactions ?? <WalletTransaction>[];
      
      state = state.copyWith(
        isWithdrawing: false,
        balance: newBalance,
        transactions: [transaction, ...existingTransactions],
        withdrawalSuccess: 'Successfully withdrew ${Formatters.formatCurrency(amount)}',
      );
    } catch (e) {
      state = state.copyWith(
        isWithdrawing: false,
        errorMessage: 'Withdrawal failed: ${e.toString()}',
      );
    }
  }

  // ===== NEW METHOD: Deduct Tokens (Called by processing provider) =====
  Future<void> deductTokens({
    required int amount,
    required String transactionId,
    required String customerPhone,
    required String productId,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Call repository to deduct tokens
      await _walletRepository.deductTokens(
        amount: amount,
        transactionId: transactionId,
        customerPhone: customerPhone,
        productId: productId,
      );

      // Refresh balance after deduction
      final newBalance = await _walletRepository.getWalletBalance();
      
      // Refresh transactions to show the deduction
      final transactions = await _walletRepository.getWalletTransactions(limit: 10);

      state = state.copyWith(
        isLoading: false,
        balance: newBalance,
        transactions: transactions,
        hasMore: transactions.length >= 10,
      );

      AppLogger.logTransaction(
        type: 'Token Deduction',
        phone: customerPhone,
        amount: amount.toDouble(),
        status: 'SUCCESS',
        reference: transactionId,
      );
    } catch (e) {
      AppLogger.e('Failed to deduct tokens:', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to deduct tokens: ${e.toString()}',
      );
    }
  }
  // =====================================================================

  Future<void> confirmPayment(String transactionId) async {
    if (state.isConfirmingPayment) return;

    state = state.copyWith(isConfirmingPayment: true, errorMessage: null);

    try {
      final confirmation = await _walletRepository.confirmPayment(transactionId);

      final existingTransactions = state.transactions ?? <WalletTransaction>[];
      final updatedTransactions = existingTransactions.map((t) {
        if (t.id == transactionId) {
          return t.copyWith(
            status: confirmation.status == 'SUCCESS'
                ? WalletTransactionStatus.success
                : WalletTransactionStatus.failed,
          );
        }
        return t;
      }).toList();

      if (confirmation.status == 'SUCCESS') {
        final newBalance = await _walletRepository.getWalletBalance();
        state = state.copyWith(balance: newBalance);
      }

      state = state.copyWith(
        isConfirmingPayment: false,
        transactions: updatedTransactions,
        pendingTransaction: null,
      );
    } catch (e) {
      state = state.copyWith(
        isConfirmingPayment: false,
        errorMessage: 'Failed to confirm payment: ${e.toString()}',
      );
    }
  }

  void selectPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null, transferSuccess: null, withdrawalSuccess: null);
  }
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepository, ref);
});