import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/payment_notification.dart';
import '../../../../shared/repositories/transaction_repository.dart';
import '../../../../shared/repositories/wallet_repository.dart';
import '../../../ussd/services/ussd_service.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/logger.dart';

// ============================================================
// TEST MODE FLAG
// Set to true during testing to bypass token balance checks.
// Set to false before going live with real agents.
// ============================================================
const bool kTestMode = true;
// Set to true to disable backend polling during USSD engine testing
const bool kDisableBackendPolling = false;

enum ProcessingMode { express, advanced }
enum ProcessingStatus { stopped, running, paused }

class ProcessingState {
  final ProcessingStatus status;
  final ProcessingMode mode;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int transactionsProcessed;
  final int tokensConsumed;
  final double todayRevenue;
  final List<ProcessedTransaction> recentTransactions;
  final String? lastError;
  final bool isCheckingPayments;
  final DateTime? lastCheckTime;

  ProcessingState({
    this.status = ProcessingStatus.stopped,
    this.mode = ProcessingMode.express,
    this.startedAt,
    this.pausedAt,
    this.transactionsProcessed = 0,
    this.tokensConsumed = 0,
    this.todayRevenue = 0.0,
    this.recentTransactions = const [],
    this.lastError,
    this.isCheckingPayments = false,
    this.lastCheckTime,
  });

  bool get canProcess => status == ProcessingStatus.running;

  bool get hasEnoughTokens => true;

  ProcessingState copyWith({
    ProcessingStatus? status,
    ProcessingMode? mode,
    DateTime? startedAt,
    DateTime? pausedAt,
    int? transactionsProcessed,
    int? tokensConsumed,
    double? todayRevenue,
    List<ProcessedTransaction>? recentTransactions,
    String? lastError,
    bool? isCheckingPayments,
    DateTime? lastCheckTime,
  }) {
    return ProcessingState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      transactionsProcessed: transactionsProcessed ?? this.transactionsProcessed,
      tokensConsumed: tokensConsumed ?? this.tokensConsumed,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      lastError: lastError,
      isCheckingPayments: isCheckingPayments ?? this.isCheckingPayments,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
    );
  }
}

class ProcessedTransaction {
  final String id;
  final String customerPhone;
  final double amount;
  final String product;
  final DateTime timestamp;
  final bool success;
  final int tokensUsed;

  ProcessedTransaction({
    required this.id,
    required this.customerPhone,
    required this.amount,
    required this.product,
    required this.timestamp,
    required this.success,
    required this.tokensUsed,
  });
}

final processingProvider =
    StateNotifierProvider<ProcessingNotifier, ProcessingState>((ref) {
  return ProcessingNotifier(ref);
});

class ProcessingNotifier extends StateNotifier<ProcessingState> {
  final Ref _ref;
  Timer? _paymentCheckTimer;
  bool _isProcessing = false;

  ProcessingNotifier(this._ref) : super(ProcessingState());

  Future<void> startProcessing() async {
    try {
      // Check if agent has till/paybill set up
      final authState = _ref.read(authNotifierProvider);
      final agent = authState.agent;

      if (agent?.tillNumber == null && agent?.paybillNumber == null) {
        state = state.copyWith(
          lastError: 'Please set up your payment method first',
        );
        _showPaymentSetupRequired();
        return;
      }

      // TOKEN CHECK — skipped entirely in test mode
      if (!kTestMode) {
        final walletState = _ref.read(walletNotifierProvider);
        final tokenBalance = walletState.balance?.availableBalance ?? 0;

        if (tokenBalance <= 0) {
          state = state.copyWith(
            lastError: 'Insufficient tokens. Please purchase tokens first.',
          );
          _showInsufficientTokens();
          return;
        }
      } else {
        AppLogger.d('[TEST MODE] Token balance check bypassed for startProcessing');
      }

      state = state.copyWith(
        status: ProcessingStatus.running,
        startedAt: DateTime.now(),
        lastError: null,
      );

      _startPaymentMonitoring();

      AppLogger.logSessionEvent(
        event: kTestMode ? '[TEST MODE] Processing started' : 'Processing started',
        details: 'Mode: ${state.mode}',
      );
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to start processing: ${e.toString()}',
      );
    }
  }

  void pauseProcessing() {
    state = state.copyWith(
      status: ProcessingStatus.paused,
      pausedAt: DateTime.now(),
    );
    _paymentCheckTimer?.cancel();
    AppLogger.logSessionEvent(event: 'Processing paused');
  }

  void stopProcessing() {
    state = ProcessingState(
      mode: state.mode,
      transactionsProcessed: state.transactionsProcessed,
      tokensConsumed: state.tokensConsumed,
      todayRevenue: state.todayRevenue,
      recentTransactions: state.recentTransactions,
    );
    _paymentCheckTimer?.cancel();
    AppLogger.logSessionEvent(event: 'Processing stopped');
  }

  void setMode(ProcessingMode mode) {
    state = state.copyWith(mode: mode);
    AppLogger.logSessionEvent(
      event: 'Processing mode changed',
      details: 'New mode: $mode',
    );
  }

  void _startPaymentMonitoring() {
  _paymentCheckTimer?.cancel();
  
  // Skip backend polling during USSD engine testing
  if (kDisableBackendPolling) {
    AppLogger.d('[TEST MODE] Backend polling disabled - using native SMS listener only');
    return;
  }
  
  _paymentCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (state.status == ProcessingStatus.running && !_isProcessing) {
      _checkForPayments();
    }
  });
}

  Future<void> _checkForPayments() async {
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(
        isCheckingPayments: true, lastCheckTime: DateTime.now());

    try {
      final authState = _ref.read(authNotifierProvider);
      final agent = authState.agent;

      if (agent == null) return;

      final walletRepo = _ref.read(walletRepositoryProvider);
      final payments = await walletRepo.checkForPayments(
        tillNumber: agent.tillNumber,
        paybillNumber: agent.paybillNumber,
        lastCheckTime: state.lastCheckTime,
      );

      for (final payment in payments) {
        await _processPayment(payment);
      }
    } catch (e) {
      AppLogger.e('Payment check failed:', e);
    } finally {
      _isProcessing = false;
      state = state.copyWith(isCheckingPayments: false);
    }
  }

  Future<void> _processPayment(PaymentNotification payment) async {
    try {
      // TOKEN CHECK PER TRANSACTION — skipped in test mode
      if (!kTestMode) {
        final walletState = _ref.read(walletNotifierProvider);
        final tokenBalance = walletState.balance?.availableBalance ?? 0;

        if (tokenBalance < 1) {
          stopProcessing();
          state = state.copyWith(
            lastError: 'Processing stopped: Insufficient tokens',
          );
          return;
        }
      } else {
        AppLogger.d('[TEST MODE] Per-transaction token check bypassed');
      }

      final transactionRepo = _ref.read(transactionRepositoryProvider);
      final product =
          await transactionRepo.findProductByPrice(payment.amount);

      if (product == null) {
        AppLogger.w('No product found for amount: ${payment.amount}');
        return;
      }

      bool ussdSuccess;
      if (state.mode == ProcessingMode.express) {
        ussdSuccess = await _executeExpressUssd(
          product.ussdCode,
          payment.customerPhone,
        );
      } else {
        ussdSuccess = await _executeAdvancedUssd(
          product.ussdCode,
          payment.customerPhone,
        );
      }

      if (ussdSuccess) {
        // In test mode we skip actual token deduction from backend
        if (!kTestMode) {
          await _ref.read(walletNotifierProvider.notifier).deductTokens(
                amount: 1,
                transactionId: payment.transactionId,
                customerPhone: payment.customerPhone,
                productId: product.id,
              );
        } else {
          AppLogger.d('[TEST MODE] Token deduction skipped');
        }

        final transaction = await _ref
            .read(transactionProvider.notifier)
            .recordTransaction(
              customerPhone: payment.customerPhone,
              amount: payment.amount,
              productId: product.id,
              reference: payment.transactionId,
            );

        final newTransaction = ProcessedTransaction(
          id: transaction.id,
          customerPhone: payment.customerPhone,
          amount: payment.amount,
          product: product.name,
          timestamp: DateTime.now(),
          success: true,
          tokensUsed: kTestMode ? 0 : 1,
        );

        state = state.copyWith(
          transactionsProcessed: state.transactionsProcessed + 1,
          tokensConsumed: kTestMode ? state.tokensConsumed : state.tokensConsumed + 1,
          todayRevenue: state.todayRevenue + payment.amount,
          recentTransactions: [newTransaction, ...state.recentTransactions]
              .take(10)
              .toList(),
        );

        AppLogger.logTransaction(
          type: product.type.toString(),
          phone: payment.customerPhone,
          amount: payment.amount,
          status: 'SUCCESS',
          reference: payment.transactionId,
        );
      } else {
        AppLogger.logTransaction(
          type: product.type.toString(),
          phone: payment.customerPhone,
          amount: payment.amount,
          status: 'FAILED',
          reference: payment.transactionId,
        );
      }
    } catch (e) {
      AppLogger.e('Payment processing failed:', e);
    }
  }

  Future<bool> _executeExpressUssd(
      String ussdCode, String customerPhone) async {
    try {
      return await _ref.read(ussdServiceProvider).executeUssd(
            ussdCode: ussdCode,
            phoneNumber: customerPhone,
          );
    } catch (e) {
      AppLogger.e('Express USSD execution failed:', e);
      return false;
    }
  }

  Future<bool> _executeAdvancedUssd(
      String ussdCode, String customerPhone) async {
    try {
      return await _ref.read(ussdServiceProvider).executeAdvancedUssd(
            ussdCode: ussdCode,
            phoneNumber: customerPhone,
          );
    } catch (e) {
      AppLogger.e('Advanced USSD execution failed:', e);
      return false;
    }
  }

  void _showPaymentSetupRequired() {}

  void _showInsufficientTokens() {}

  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    super.dispose();
  }
}