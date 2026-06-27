// lib/features/offers/presentation/providers/offer_provider.dart
// W2.4B: offers management state. Wraps OfferRepository (Batch 3, speaks
// OfferType/ussdCode). Filter is an OfferType? where null = "All". The list
// is agent-scoped server-side (JWT), so no agentId is passed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/repositories/offer_repository.dart';

class OffersState {
  final bool isLoading;
  final List<Offer> offers;
  final OfferType? filter; // null = All
  final String? errorMessage;
  final bool isMutating; // create/update/delete/toggle in flight

  const OffersState({
    this.isLoading = false,
    this.offers = const [],
    this.filter,
    this.errorMessage,
    this.isMutating = false,
  });

  OffersState copyWith({
    bool? isLoading,
    List<Offer>? offers,
    OfferType? filter,
    bool clearFilter = false,
    String? errorMessage,
    bool clearError = false,
    bool? isMutating,
  }) {
    return OffersState(
      isLoading: isLoading ?? this.isLoading,
      offers: offers ?? this.offers,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
    );
  }
}

class OffersNotifier extends StateNotifier<OffersState> {
  final OfferRepository _repository;
  OffersNotifier(this._repository) : super(const OffersState());

  Future<void> loadOffers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offers = await _repository.getOffers(
        type: state.filter, // null → backend returns all types
        limit: 100,
      );
      state = state.copyWith(isLoading: false, offers: offers);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load offers: ${e.toString()}',
      );
    }
  }

  /// Sets the active filter (null = All) and reloads.
  Future<void> setFilter(OfferType? type) async {
    if (type == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filter: type);
    }
    await loadOffers();
  }

  Future<bool> createOffer({
    required String name,
    required String ussdCode,
    required int price,
    required OfferType type,
    bool isActive = true,
    double? commissionRate,
    OfferProcessingMode? processingMode,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.createOffer(
        name: name,
        ussdCode: ussdCode,
        price: price,
        type: type,
        isActive: isActive,
        commissionRate: commissionRate,
        processingMode: processingMode,
      );
      state = state.copyWith(isMutating: false);
      await loadOffers();
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        errorMessage: 'Failed to create offer: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> updateOffer(
    String id, {
    String? name,
    String? ussdCode,
    int? price,
    OfferType? type,
    bool? isActive,
    double? commissionRate,
    OfferProcessingMode? processingMode,
    bool setProcessingMode = false,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.updateOffer(
        id,
        name: name,
        ussdCode: ussdCode,
        price: price,
        type: type,
        isActive: isActive,
        commissionRate: commissionRate,
        processingMode: processingMode,
        setProcessingMode: setProcessingMode,
      );
      state = state.copyWith(isMutating: false);
      await loadOffers();
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        errorMessage: 'Failed to update offer: ${e.toString()}',
      );
      return false;
    }
  }

  /// Optimistic toggle: flip locally, call backend, revert on failure.
  Future<void> toggleActive(String id, bool isActive) async {
    final original = state.offers;
    state = state.copyWith(
      offers: [
        for (final o in original)
          if (o.id == id) o.copyWith(isActive: isActive) else o,
      ],
    );
    try {
      await _repository.toggleActive(id, isActive);
    } catch (e) {
      // Revert.
      state = state.copyWith(
        offers: original,
        errorMessage: 'Failed to update offer status: ${e.toString()}',
      );
    }
  }

  Future<bool> deleteOffer(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.deleteOffer(id);
      state = state.copyWith(
        isMutating: false,
        offers: [
          for (final o in state.offers)
            if (o.id != id) o,
        ],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        errorMessage: 'Failed to delete offer: ${e.toString()}',
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final offersNotifierProvider =
    StateNotifierProvider<OffersNotifier, OffersState>((ref) {
  final repository = ref.watch(offerRepositoryProvider);
  return OffersNotifier(repository);
});