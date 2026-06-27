// lib/features/quick_dial/presentation/providers/quick_dial_provider.dart
//
// W3.L — Quick Dial routed through the REAL pipeline (Hybrid parity).
//
// Before (W2.4C stopgap): createQuickDial (born SUCCESS) → fire-and-forget
// Express dial via UssdService.executeUssd. No response capture, no retry, no
// auto-reply, no status. The W2 primer flagged this as a deliberate stopgap.
//
// After (W3.L): mirrors Hybrid's QuickDialViewModel.dial, which runs Quick Dial
// through the same DialUssdUseCase → pipeline as every other dial:
//   1. Validate (offer selected; phone normalized) — verbatim Hybrid messages.
//   2. createQuickDial → backend now creates a SCHEDULED txn + debits at
//      dial-time (D-W3-17), returning the txn (id, ussdCode, customerPhone,
//      offerId, amount, offerName).
//   3. Enqueue that txn into the native pipeline (UssdExecutionService) via
//      SessionBridge.enqueueQuickDial — Express/Advanced per mode, internal
//      retry, classify, auto-reply, status PATCH, all shared with SMS/scheduled.
//   4. Observe the outcome by polling GET /transactions/:id/status (Pro's
//      stand-in for Hybrid's observeTransactionStatusUseCase) until terminal,
//      then surface (success, responseText) to the UssdResponseDialog.
//
// The old UssdService dependency is GONE — Quick Dial no longer dials directly;
// the pipeline owns the dial. Auto-reply fires for QD too (Hybrid doesn't skip
// QUICK_DIAL), so a successful manual dial also texts the customer.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/ussd_template_formatter.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/repositories/transaction_repository.dart';

enum QuickDialPhase { idle, recording, dialing, success, error }

class QuickDialState {
  final Offer? selectedOffer;
  final String customerPhone; // raw user input
  final QuickDialPhase phase;
  final String? errorMessage;
  final bool needsSubscription; // true when backend returned 402
  // W3.L: terminal pipeline result for the UssdResponseDialog.
  final bool dialedSuccess;
  final String? ussdResponse;
  final bool showResultDialog;
  const QuickDialState({
    this.selectedOffer,
    this.customerPhone = '',
    this.phase = QuickDialPhase.idle,
    this.errorMessage,
    this.needsSubscription = false,
    this.dialedSuccess = false,
    this.ussdResponse,
    this.showResultDialog = false,
  });
  bool get isBusy =>
      phase == QuickDialPhase.recording || phase == QuickDialPhase.dialing;
  QuickDialState copyWith({
    Offer? selectedOffer,
    bool clearOffer = false,
    String? customerPhone,
    QuickDialPhase? phase,
    String? errorMessage,
    bool clearError = false,
    bool? needsSubscription,
    bool? dialedSuccess,
    String? ussdResponse,
    bool clearResponse = false,
    bool? showResultDialog,
  }) {
    return QuickDialState(
      selectedOffer: clearOffer ? null : (selectedOffer ?? this.selectedOffer),
      customerPhone: customerPhone ?? this.customerPhone,
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsSubscription: needsSubscription ?? this.needsSubscription,
      dialedSuccess: dialedSuccess ?? this.dialedSuccess,
      ussdResponse: clearResponse ? null : (ussdResponse ?? this.ussdResponse),
      showResultDialog: showResultDialog ?? this.showResultDialog,
    );
  }
}

class QuickDialNotifier extends StateNotifier<QuickDialState> {
  final TransactionRepository _transactionRepository;
  final SessionBridgeService _sessionBridge;
  QuickDialNotifier(this._transactionRepository, this._sessionBridge)
      : super(const QuickDialState());

  // Status-poll cadence + cap (Pro's stand-in for observeTransactionStatusUseCase).
  // The pipeline does an internal retry + up to the offer's external retries, so
  // we poll generously: 2s × 60 = up to ~2 min before giving up the *observation*
  // (the dial/debit already happened server-side regardless).
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPolls = 60;

  // Backend status STRINGS that are terminal. Compared directly because the poll now
  // reads the SLIM /status payload via getTransactionStatusLite — routing that through
  // TransactionResponse.fromJson threw `type 'Null' is not a subtype of type 'String'`
  // on every tick (the slim shape lacks the full model's required fields), the poll's
  // catch swallowed it, and the result dialog hung on its spinner to the cap. This
  // mirrors the pay-with-airtime sheet's fix.
  static const Set<String> _terminalStatuses = {
    'SUCCESS',
    'FAILED',
    'FAILED_ALREADY_RECOMMENDED',
    'FAILED_OFFER_DEACTIVATED',
    'BLOCKED',
  };

  void selectOffer(Offer offer) {
    state = state.copyWith(
      selectedOffer: offer,
      clearError: true,
      needsSubscription: false,
      phase: QuickDialPhase.idle,
    );
  }

  void setCustomerPhone(String phone) {
    state = state.copyWith(customerPhone: phone);
  }

  void reset() {
    state = state.copyWith(
      phase: QuickDialPhase.idle,
      clearError: true,
      needsSubscription: false,
    );
  }

  /// Dismiss the result dialog (and clear the captured response).
  void dismissResultDialog() {
    state = state.copyWith(
      showResultDialog: false,
      clearResponse: true,
      dialedSuccess: false,
    );
  }

  /// The dial sequence. Backend-first; routes through the real pipeline.
  Future<void> dial() async {
    if (state.isBusy) return;
    final offer = state.selectedOffer;
    // Validation messages verbatim from Hybrid QuickDialViewModel.dial.
    if (offer == null) {
      state = state.copyWith(
        phase: QuickDialPhase.error,
        errorMessage: 'You have not selected any offer',
      );
      return;
    }
    final String normalizedPhone;
    try {
      normalizedPhone = normalizeKenyanPhone(state.customerPhone);
    } catch (_) {
      state = state.copyWith(
        phase: QuickDialPhase.error,
        errorMessage: 'Enter a valid customer phone number',
      );
      return;
    }
    // 1. Backend record + 402-guard (now creates SCHEDULED + debits at dial-time).
    state = state.copyWith(
      phase: QuickDialPhase.recording,
      clearError: true,
      needsSubscription: false,
      clearResponse: true,
    );
    try {
      final response = await _transactionRepository.createQuickDial(
        offerId: offer.id,
        customerPhone: normalizedPhone,
      );
      final sc = response.statusCode ?? 0;
      if (sc == 402) {
        state = state.copyWith(
          phase: QuickDialPhase.error,
          needsSubscription: true,
          errorMessage:
              'No active subscription. Please subscribe, then retry.',
        );
        return;
      }
      if (sc < 200 || sc >= 300) {
        String msg = 'Could not record the transaction';
        final data = response.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        }
        state = state.copyWith(
          phase: QuickDialPhase.error,
          errorMessage: msg,
        );
        return;
      }

      // 2. Extract the SCHEDULED txn fields the pipeline needs.
      final data = response.data;
      if (data is! Map) {
        state = state.copyWith(
          phase: QuickDialPhase.error,
          errorMessage: 'Unexpected server response',
        );
        return;
      }
      final txnId = (data['id'] ?? '').toString();
      final ussdCode = (data['ussdCode'] ?? '').toString();
      if (txnId.isEmpty || ussdCode.isEmpty) {
        state = state.copyWith(
          phase: QuickDialPhase.error,
          errorMessage: 'Server did not return a dialable transaction',
        );
        return;
      }
      final int? amount = _asInt(data['amount']);

      // 3. Enqueue into the real pipeline (Express/Advanced per mode, retry,
      //    classify, auto-reply, status). The native side reads token/baseUrl.
      state = state.copyWith(phase: QuickDialPhase.dialing);
      AppLogger.d('Quick Dial: enqueueing txn=$txnId into pipeline');
      final enqueued = await _sessionBridge.enqueueQuickDial(
        transactionId: txnId,
        ussdCode: ussdCode,
        customerPhone: normalizedPhone,
        offerId: offer.id,
        offerName: offer.name,
        amount: amount,
        offerPrice: offer.price,
        // Per-offer dial mode override; null = the agent's global mode.
        processingMode: offer.processingMode?.wire,
      );
      if (!enqueued) {
        state = state.copyWith(
          phase: QuickDialPhase.error,
          errorMessage:
              'Transaction recorded, but the dial could not start. '
              'Check that call permission is granted, then retry.',
        );
        return;
      }

      // 4. Observe the outcome (poll /:id/status until terminal) → result dialog.
      await _observeStatus(txnId);
    } catch (e) {
      state = state.copyWith(
        phase: QuickDialPhase.error,
        errorMessage: 'Quick Dial failed: ${e.toString()}',
      );
    }
  }

  /// Poll the transaction status until terminal (or cap), then surface the
  /// result to the UssdResponseDialog. Mirrors observeTransactionStatusUseCase.
  Future<void> _observeStatus(String transactionId) async {
    for (var i = 0; i < _maxPolls; i++) {
      await Future.delayed(_pollInterval);
      ({String status, String responseText}) s;
      try {
        s = await _transactionRepository.getTransactionStatusLite(transactionId);
      } catch (e) {
        // Transient read error — keep polling; the pipeline is still running.
        AppLogger.d('Quick Dial status poll error (continuing): $e');
        continue;
      }
      if (!_terminalStatuses.contains(s.status)) continue;

      final success = s.status == 'SUCCESS';
      final responseText = s.responseText.trim().isNotEmpty
          ? s.responseText
          : (success ? 'Request successful' : 'Request failed');
      state = state.copyWith(
        phase: success ? QuickDialPhase.success : QuickDialPhase.error,
        dialedSuccess: success,
        ussdResponse: responseText,
        showResultDialog: true,
        clearError: true,
      );
      if (success) {
        // Hybrid clears phone + offer on success.
        state = state.copyWith(customerPhone: '', clearOffer: true);
      }
      return;
    }
    // Cap reached without a terminal status — the dial/debit already happened;
    // we just couldn't observe the final result in time.
    state = state.copyWith(
      phase: QuickDialPhase.success,
      dialedSuccess: true,
      ussdResponse:
          'Dial sent. The result is taking longer than usual — check '
          'Transaction History for the final status.',
      showResultDialog: true,
      clearError: true,
    );
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return double.tryParse(v)?.toInt();
    return null;
  }
}

final quickDialNotifierProvider =
    StateNotifierProvider<QuickDialNotifier, QuickDialState>((ref) {
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  final sessionBridge = ref.watch(sessionBridgeServiceProvider);
  return QuickDialNotifier(transactionRepository, sessionBridge);
});