// lib/features/offers/presentation/providers/offer_settings_provider.dart
// W3.H — Offer Settings state + notifier, mirroring Hybrid's OfferSettingsViewModel:
//   - loadOffer(id): pulls the offer, ussdTimeoutMillis ÷ 1000 → ussdTimeoutSeconds
//     (updateStatesFromDatabase in Hybrid).
//   - Each setter updates local state THEN immediately persists that single field
//     via PATCH /offers/:id — Hybrid auto-saves on every change (each updateXxx()
//     ends by calling updateOffer()); there is no Save button for these 7 fields.
//   - ussdTimeout is shown/edited in seconds but stored as ussdTimeoutMillis (× 1000).
// relayDevice is NOT exposed (W5).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/repositories/offer_repository.dart';

class OfferSettingsState {
  final String offerId;
  final bool isLoading;
  // The 7 editable fields (Hybrid OfferSettingsState):
  final bool autoReschedule;
  final String? autoRescheduleRunTime;
  final bool autoRetry;
  final bool autoRetryConnectionProblems;
  final int numberOfRetries;
  final int retryIntervalMins;
  final int ussdTimeoutSeconds; // stored as ussdTimeoutMillis (× 1000)
  final String? errorMessage;

  const OfferSettingsState({
    required this.offerId,
    this.isLoading = true,
    this.autoReschedule = false,
    this.autoRescheduleRunTime,
    this.autoRetry = false,
    this.autoRetryConnectionProblems = false,
    this.numberOfRetries = 0,
    this.retryIntervalMins = 5,
    this.ussdTimeoutSeconds = 60,
    this.errorMessage,
  });

  OfferSettingsState copyWith({
    bool? isLoading,
    bool? autoReschedule,
    String? autoRescheduleRunTime,
    bool? autoRetry,
    bool? autoRetryConnectionProblems,
    int? numberOfRetries,
    int? retryIntervalMins,
    int? ussdTimeoutSeconds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OfferSettingsState(
      offerId: offerId,
      isLoading: isLoading ?? this.isLoading,
      autoReschedule: autoReschedule ?? this.autoReschedule,
      autoRescheduleRunTime:
          autoRescheduleRunTime ?? this.autoRescheduleRunTime,
      autoRetry: autoRetry ?? this.autoRetry,
      autoRetryConnectionProblems:
          autoRetryConnectionProblems ?? this.autoRetryConnectionProblems,
      numberOfRetries: numberOfRetries ?? this.numberOfRetries,
      retryIntervalMins: retryIntervalMins ?? this.retryIntervalMins,
      ussdTimeoutSeconds: ussdTimeoutSeconds ?? this.ussdTimeoutSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class OfferSettingsNotifier extends StateNotifier<OfferSettingsState> {
  final OfferRepository _repository;

  OfferSettingsNotifier(this._repository, String offerId)
      : super(OfferSettingsState(offerId: offerId)) {
    loadOffer();
  }

  /// Hybrid loadOffer(UUID) → updateStatesFromDatabase(Offer).
  Future<void> loadOffer() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offer = await _repository.getOfferById(state.offerId);
      state = state.copyWith(
        isLoading: false,
        autoReschedule: offer.autoReschedule,
        autoRescheduleRunTime: offer.autoRescheduleRunTime,
        autoRetry: offer.autoRetry,
        autoRetryConnectionProblems: offer.autoRetryConnectionProblems,
        numberOfRetries: offer.numberOfRetries,
        retryIntervalMins: offer.retryIntervalMins,
        // ms ÷ 1000 → seconds (Hybrid div-long const 1000).
        ussdTimeoutSeconds: (offer.ussdTimeoutMillis / 1000).round(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load settings: $e',
      );
    }
  }

  // ── Per-field setters (optimistic local update + immediate single-field PATCH) ──
  // Each mirrors a Hybrid updateXxx() that ends by calling updateOffer().

  Future<void> updateUssdTimeout(int seconds) async {
    state = state.copyWith(ussdTimeoutSeconds: seconds);
    await _patch(ussdTimeoutMillis: seconds * 1000);
  }

  Future<void> updateAutoRetry(bool value) async {
    state = state.copyWith(autoRetry: value);
    await _patch(autoRetry: value);
  }

  Future<void> updateNumberOfRetries(int value) async {
    state = state.copyWith(numberOfRetries: value);
    await _patch(numberOfRetries: value);
  }

  Future<void> updateRetryInterval(int minutes) async {
    state = state.copyWith(retryIntervalMins: minutes);
    await _patch(retryIntervalMins: minutes);
  }

  Future<void> updateAutoRetryConnectionProblems(bool value) async {
    state = state.copyWith(autoRetryConnectionProblems: value);
    await _patch(autoRetryConnectionProblems: value);
  }

  Future<void> updateAutoReschedule(bool value) async {
    state = state.copyWith(autoReschedule: value);
    await _patch(autoReschedule: value);
  }

  Future<void> updateRescheduleTime(String time) async {
    state = state.copyWith(autoRescheduleRunTime: time);
    await _patch(autoRescheduleRunTime: time);
  }

  /// Single-field PATCH /offers/:id. Best-effort: surfaces an error message but
  /// keeps the optimistic local value (Hybrid does not revert on failure either).
  Future<void> _patch({
    bool? autoReschedule,
    String? autoRescheduleRunTime,
    bool? autoRetry,
    bool? autoRetryConnectionProblems,
    int? numberOfRetries,
    int? retryIntervalMins,
    int? ussdTimeoutMillis,
  }) async {
    try {
      await _repository.updateOffer(
        state.offerId,
        autoReschedule: autoReschedule,
        autoRescheduleRunTime: autoRescheduleRunTime,
        autoRetry: autoRetry,
        autoRetryConnectionProblems: autoRetryConnectionProblems,
        numberOfRetries: numberOfRetries,
        retryIntervalMins: retryIntervalMins,
        ussdTimeoutMillis: ussdTimeoutMillis,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save: $e');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Family keyed by offerId — each offer's settings are isolated and load on first read.
final offerSettingsProvider = StateNotifierProvider.family<OfferSettingsNotifier,
    OfferSettingsState, String>((ref, offerId) {
  final repository = ref.watch(offerRepositoryProvider);
  return OfferSettingsNotifier(repository, offerId);
});