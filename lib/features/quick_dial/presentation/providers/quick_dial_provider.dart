// lib/features/quick_dial/presentation/providers/quick_dial_provider.dart
// W2.4C Quick Dial. Mirrors Hybrid's QuickDialViewModel.dial() order:
//   1. normalize customer phone (normalizeKenyanPhone — matches Hybrid's
//      takeLast(9)+"0").
//   2. POST /transactions via createQuickDial (the 402-guard gate). dio
//      validateStatus<500 → 402/400/404 resolve, not throw → inspect statusCode.
//   3. ONLY on 2xx: substitute BH via UssdTemplateFormatter, then Express-dial
//      through the existing UssdService (bingwa_pro/ussd → ACTION_CALL).
// Advanced/accessibility routing + live status streaming are W3. W2 is
// Express-only (matches Hybrid's behavior when accessibility is unavailable).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/ussd_template_formatter.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/repositories/transaction_repository.dart';
import '../../../ussd/services/ussd_service.dart';

enum QuickDialPhase { idle, recording, dialing, success, error }

class QuickDialState {
  final Offer? selectedOffer;
  final String customerPhone; // raw user input
  final QuickDialPhase phase;
  final String? errorMessage;
  final bool needsSubscription; // true when backend returned 402

  const QuickDialState({
    this.selectedOffer,
    this.customerPhone = '',
    this.phase = QuickDialPhase.idle,
    this.errorMessage,
    this.needsSubscription = false,
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
  }) {
    return QuickDialState(
      selectedOffer: clearOffer ? null : (selectedOffer ?? this.selectedOffer),
      customerPhone: customerPhone ?? this.customerPhone,
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsSubscription: needsSubscription ?? this.needsSubscription,
    );
  }
}

class QuickDialNotifier extends StateNotifier<QuickDialState> {
  final TransactionRepository _transactionRepository;
  final UssdService _ussdService;

  QuickDialNotifier(this._transactionRepository, this._ussdService)
      : super(const QuickDialState());

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

  /// The dial sequence. Backend-first; dials only on confirmed entitlement.
  Future<void> dial() async {
    if (state.isBusy) return;

    final offer = state.selectedOffer;
    if (offer == null) {
      state = state.copyWith(
        phase: QuickDialPhase.error,
        errorMessage: 'You have not selected any offer',
      );
      return;
    }

    // 1. Normalize phone (Hybrid parity). Reject too-short input early.
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

    // 2. Backend record + 402-guard.
    state = state.copyWith(
      phase: QuickDialPhase.recording,
      clearError: true,
      needsSubscription: false,
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

      // 3. Backend confirmed → substitute BH → Express-dial.
      final ussdCode = UssdTemplateFormatter.format(
        offer.ussdCode,
        phone: normalizedPhone,
      );
      AppLogger.d('Quick Dial: dialing $ussdCode for $normalizedPhone');

      state = state.copyWith(phase: QuickDialPhase.dialing);

      final dialed = await _ussdService.executeUssd(
        ussdCode: ussdCode,
        phoneNumber: normalizedPhone,
      );

      if (dialed) {
        state = state.copyWith(phase: QuickDialPhase.success);
      } else {
        // Backend already recorded; dial intent failed (permission/dialer).
        state = state.copyWith(
          phase: QuickDialPhase.error,
          errorMessage:
              'Transaction recorded, but the dial could not start. '
              'Check that call permission is granted, then retry.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: QuickDialPhase.error,
        errorMessage: 'Quick Dial failed: ${e.toString()}',
      );
    }
  }
}

final quickDialNotifierProvider =
    StateNotifierProvider<QuickDialNotifier, QuickDialState>((ref) {
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  final ussdService = ref.watch(ussdServiceProvider);
  return QuickDialNotifier(transactionRepository, ussdService);
});