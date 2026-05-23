// lib/features/dashboard/presentation/providers/processing_provider.dart
// W1 edits per Q3 lock:
//   - _checkForPayments() body stubbed with AppLogger + return
//   - _processPayment() body stubbed with AppLogger + return
//   - State machine, timer plumbing, mode setter, public API all preserved
//   - Token-balance read in startProcessing() updated to use hasUsableTokens
// The full auto-processing-of-incoming-payments pipeline is W2/W3 territory.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../../core/utils/logger.dart';

// ============================================================
// TEST MODE FLAG
// Set to true during testing to bypass plan checks.
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
      transactionsProcessed:
          transactionsProcessed ?? this.transactionsProcessed,
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
      // W2.A (Flag A): removed dead till/paybill guard — those fields are
      // dropped (D-W2-4). Payment-method setup is no longer a precondition;
      // SIM-based identity (W4) replaces it.

      // W1: plan check via hasUsableTokens. Skipped in test mode.
      if (!kTestMode) {
        final walletState = _ref.read(walletNotifierProvider);
        final hasUsable = walletState.balance?.hasUsableTokens ?? false;
        if (!hasUsable) {
          state = state.copyWith(
            lastError: 'No active subscription plan. Please subscribe first.',
          );
          _showInsufficientTokens();
          return;
        }
      } else {
        AppLogger.d('[TEST MODE] Plan check bypassed for startProcessing');
      }
      state = state.copyWith(
        status: ProcessingStatus.running,
        startedAt: DateTime.now(),
        lastError: null,
      );
      _startPaymentMonitoring();
      AppLogger.logSessionEvent(
        event: kTestMode
            ? '[TEST MODE] Processing started'
            : 'Processing started',
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
    if (kDisableBackendPolling) {
      AppLogger.d(
          '[TEST MODE] Backend polling disabled - using native SMS listener only');
      return;
    }
    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (state.status == ProcessingStatus.running && !_isProcessing) {
        _checkForPayments();
      }
    });
  }

  // ===== W1 STUB per Q3 lock =====
  // The previous implementation called walletRepo.checkForPayments() (deleted
  // in W1) and findProductByPrice() (deleted in W1). The whole "poll backend
  // for new M-Pesa payments → look up product by amount → execute USSD" flow
  // is W2/W3 territory. Stub here keeps the timer + state machine working.
  Future<void> _checkForPayments() async {
    if (_isProcessing) return;
    _isProcessing = true;
    state = state.copyWith(
      isCheckingPayments: true,
      lastCheckTime: DateTime.now(),
    );
    try {
      AppLogger.d(
        '[W1-STUB] _checkForPayments() — auto-processing pipeline reconnected in W2',
      );
      // TODO(wave-2): reconnect to offer-execution pipeline.
      //   1. Read incoming M-Pesa payments (SMS listener already does this on Kotlin side)
      //   2. For each payment, match its amount to an active Offer
      //   3. Execute the offer's USSD template against payment.customerPhone
      //   4. Decrement the active SubscriptionPlan (LIMITED) via backend
    } catch (e) {
      AppLogger.e('Payment check stub failed:', e);
    } finally {
      _isProcessing = false;
      state = state.copyWith(isCheckingPayments: false);
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