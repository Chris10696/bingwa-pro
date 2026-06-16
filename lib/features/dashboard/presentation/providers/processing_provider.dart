// lib/features/dashboard/presentation/providers/processing_provider.dart
//
// W3.N — reconciled onto the native-backed AppState master switch.
//
// What changed from W1/W2:
//   - DELETED the duplicate `enum ProcessingMode {express, advanced}` — processing
//     mode is the single wallet-backed value (WalletBalance.wallet.processingMode,
//     wired in W3.I). Nothing here owns mode anymore.
//   - ProcessingStatus {stopped, running, paused} is now the Dart mirror of Hybrid's
//     AppState {STATE_STOPPED, STATE_RUNNING, STATE_PAUSED}. start/pause/stop persist
//     the state to native via SessionBridge.saveAppState (the SMS receiver auto-processes
//     only when AppState=='running'; the dialer reacts to it). Hybrid's DefaultAppControl
//     is pure state (persist + StateFlow), so mirroring the string IS the whole job.
//   - Transitions match Hybrid's HomeViewModel exactly:
//       start  : validateStartup() guard → RUNNING  → "Processing started successfully"
//       resume : RUNNING                            → "Processing resumed"
//       pause  : PAUSED                             → "Processing paused"
//       stop   : STOPPED                            → "Processing stopped successfully"
//     The toggle() helper cycles start/pause/resume by current state (Hybrid toggleAppState).
//   - validateStartup() ports Hybrid's startup guard for Pro's surface: starting in
//     Advanced mode requires the accessibility service; otherwise it throws the Hybrid
//     message and the state does NOT change.
//   - DELETED the 10s Dart payment-poll Timer + _checkForPayments stub. Under Option C
//     the native MpesaMessageListener is the real-time trigger (works backgrounded);
//     a Dart timer only ticked while the app was open. Status reconciliation of the
//     processed list comes from the backend (W3.G) — not a Dart poll.
//   - snackbarMessage is exposed for the dashboard to surface Hybrid's exact toasts.
//
// PAUSED semantics (Hybrid parity, decision 4): PAUSED is a distinct state, NOT a full
// stop. Hybrid's receiver ignores non-RUNNING for general M-Pesa, but `allowedWhenNotRunning`
// transaction types still dial while paused (DialPausedTransactionsUseCase). We preserve
// PAUSED as its own AppState so that door stays open; the paused-transaction dial queue
// itself is a later slice (Pro has no paused-queue yet). For now PAUSED suspends M-Pesa
// auto-processing (receiver gate is RUNNING-only) without collapsing into STOPPED.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../../shared/repositories/wallet_repository.dart';
import '../../../../shared/models/wallet_model.dart'
    show ProcessingMode, WalletBalance;
import '../../../../core/services/session_bridge_service.dart';
import '../../../../core/utils/logger.dart';

// ============================================================
// TEST MODE FLAG — W3.N: default false (real flow). Set true only to bypass the
// plan check during isolated testing.
// ============================================================
const bool kTestMode = false;

/// Dart mirror of Hybrid's AppState. Names map 1:1:
///   stopped ↔ STATE_STOPPED, running ↔ STATE_RUNNING, paused ↔ STATE_PAUSED.
enum ProcessingStatus { stopped, running, paused }

/// Thrown by validateStartup() when a precondition blocks starting. The message
/// is surfaced verbatim to the agent (Hybrid behaviour).
class StartupValidationException implements Exception {
  final String message;
  StartupValidationException(this.message);
  @override
  String toString() => message;
}

extension _AppStateWire on ProcessingStatus {
  /// Native/Hybrid wire value for SessionBridge.saveAppState.
  String get wire => switch (this) {
        ProcessingStatus.stopped => 'stopped',
        ProcessingStatus.running => 'running',
        ProcessingStatus.paused => 'paused',
      };
}

class ProcessingState {
  final ProcessingStatus status;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int transactionsProcessed;
  final int tokensConsumed;
  final double todayRevenue;
  final List<ProcessedTransaction> recentTransactions;
  final String? lastError;
  /// One-shot toast text (Hybrid's snackbarMessage). Dashboard consumes + clears it.
  final String? snackbarMessage;

  ProcessingState({
    this.status = ProcessingStatus.stopped,
    this.startedAt,
    this.pausedAt,
    this.transactionsProcessed = 0,
    this.tokensConsumed = 0,
    this.todayRevenue = 0.0,
    this.recentTransactions = const [],
    this.lastError,
    this.snackbarMessage,
  });

  bool get canProcess => status == ProcessingStatus.running;

  ProcessingState copyWith({
    ProcessingStatus? status,
    DateTime? startedAt,
    DateTime? pausedAt,
    int? transactionsProcessed,
    int? tokensConsumed,
    double? todayRevenue,
    List<ProcessedTransaction>? recentTransactions,
    String? lastError,
    String? snackbarMessage,
  }) {
    return ProcessingState(
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      transactionsProcessed:
          transactionsProcessed ?? this.transactionsProcessed,
      tokensConsumed: tokensConsumed ?? this.tokensConsumed,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      lastError: lastError,
      snackbarMessage: snackbarMessage,
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
  ProcessingNotifier(this._ref) : super(ProcessingState());

  SessionBridgeService get _bridge => _ref.read(sessionBridgeServiceProvider);

  /// Hybrid's startup guard, ported for Pro's surface. Currently the one relevant
  /// precondition: Advanced mode requires the accessibility service to be enabled.
  /// (Hybrid's other startup validations — SIM/socket — are W3.F/W5.) Throws with
  /// the verbatim Hybrid message; callers do NOT change state on throw.
  Future<void> _validateStartup() async {
    // Fetch a FRESH balance from the backend rather than reading a cached value.
    // The play button lives on the dashboard, which loads dashboardNotifierProvider —
    // a DIFFERENT provider than walletNotifierProvider. The wallet provider is only
    // populated when the agent opens the Subscription screen, so reading its cache
    // here returned a false "No active subscription plan" whenever it had not loaded
    // yet (and a stale answer otherwise) — even with a valid, token-bearing plan.
    // The backend is the single source of truth for entitlement, so ask it directly.
    // On a network failure, fall back to any cached value so a transient blip can't
    // block a known-good plan.
    WalletBalance? balance;
    try {
      balance = await _ref.read(walletRepositoryProvider).getWalletBalance();
    } catch (_) {
      balance = _ref.read(walletNotifierProvider).balance;
    }

    final mode = balance?.wallet?.processingMode ?? ProcessingMode.express;
    if (mode == ProcessingMode.advanced) {
      final enabled = await _bridge.isAccessibilityEnabled();
      if (!enabled) {
        throw StartupValidationException(
          "Failed. Advanced Mode requires Accessibility service to be enabled. "
          "Please enable it in phone's settings then retry",
        );
      }
    }
    // Plan check (skipped in test mode). Hybrid gates startup on entitlement too.
    if (!kTestMode) {
      final hasUsable = balance?.hasUsableTokens ?? false;
      if (!hasUsable) {
        throw StartupValidationException(
          'No active subscription plan. Please subscribe first.',
        );
      }
    }
  }

  /// Persist + mirror the AppState to native, then update local state.
  Future<void> _applyState(ProcessingStatus status,
      {String? snackbar, DateTime? startedAt, DateTime? pausedAt}) async {
    await _bridge.saveAppState(status.wire);
    state = state.copyWith(
      status: status,
      startedAt: startedAt,
      pausedAt: pausedAt,
      lastError: null,
      snackbarMessage: snackbar,
    );
  }

  /// START (STOPPED → RUNNING). Hybrid: validateStartup → RUNNING →
  /// "Processing started successfully".
  Future<void> startProcessing() async {
    try {
      await _validateStartup();
      await _applyState(
        ProcessingStatus.running,
        snackbar: 'Processing started successfully',
        startedAt: DateTime.now(),
      );
      AppLogger.logSessionEvent(event: 'Processing started');
    } on StartupValidationException catch (e) {
      // State unchanged; surface the message (Hybrid sets snackbar + leaves state).
      state = state.copyWith(lastError: e.message, snackbarMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to start processing: $e',
        snackbarMessage: 'Failed to start processing',
      );
    }
  }

  /// RESUME (PAUSED → RUNNING). Hybrid: validateStartup → RUNNING →
  /// "Processing resumed".
  Future<void> resumeProcessing() async {
    try {
      await _validateStartup();
      await _applyState(
        ProcessingStatus.running,
        snackbar: 'Processing resumed',
        startedAt: state.startedAt ?? DateTime.now(),
      );
      AppLogger.logSessionEvent(event: 'Processing resumed');
    } on StartupValidationException catch (e) {
      state = state.copyWith(lastError: e.message, snackbarMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to resume processing: $e',
        snackbarMessage: 'Failed to resume processing',
      );
    }
  }

  /// PAUSE (RUNNING → PAUSED). Hybrid: PAUSED → "Processing paused".
  Future<void> pauseProcessing() async {
    await _applyState(
      ProcessingStatus.paused,
      snackbar: 'Processing paused',
      startedAt: state.startedAt,
      pausedAt: DateTime.now(),
    );
    AppLogger.logSessionEvent(event: 'Processing paused');
  }

  /// STOP (→ STOPPED). Hybrid: STOPPED → "Processing stopped successfully".
  /// Resets runtime counters but preserves the session's processed list for the
  /// dashboard until the next refresh.
  Future<void> stopProcessing() async {
    await _bridge.saveAppState(ProcessingStatus.stopped.wire);
    state = ProcessingState(
      status: ProcessingStatus.stopped,
      transactionsProcessed: state.transactionsProcessed,
      tokensConsumed: state.tokensConsumed,
      todayRevenue: state.todayRevenue,
      recentTransactions: state.recentTransactions,
      snackbarMessage: 'Processing stopped successfully',
    );
    AppLogger.logSessionEvent(event: 'Processing stopped');
  }

  /// Hybrid's toggleAppState: cycles by current state.
  ///   STOPPED → start ; RUNNING → pause ; PAUSED → resume.
  Future<void> toggleProcessing() async {
    switch (state.status) {
      case ProcessingStatus.stopped:
        await startProcessing();
        break;
      case ProcessingStatus.running:
        await pauseProcessing();
        break;
      case ProcessingStatus.paused:
        await resumeProcessing();
        break;
    }
  }

  /// Dashboard calls this after showing the snackbar so it fires once.
  void clearSnackbar() {
    if (state.snackbarMessage != null) {
      state = state.copyWith(snackbarMessage: null);
    }
  }
}