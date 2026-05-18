// lib/features/wallet/presentation/providers/wallet_provider.dart
// W1: rewritten.
//   STATE (new shape):
//     - balance: WalletBalance (composite payload: hasUsableTokens, plans, wallet)
//     - packages: List<SubscriptionPackage>?  (Q7 — fetched in loadWalletData)
//     - purchases: List<SubscriptionPurchase>? (renamed from transactions, Q5)
//     - pendingPurchase: SubscriptionPurchase? (renamed from pendingTransaction)
//     - isPurchasingSubscription: bool (renamed from isPurchasingTokens)
//   METHODS:
//     - loadWalletData(): now parallel-fetches balance + packages + purchases
//     - loadMorePurchases() (renamed)
//     - purchaseSubscription(packageId): replaces purchaseTokens()
//     - confirmPayment(purchaseId): preserved
//   DELETED entirely:
//     - transferTokens, withdrawTokens, deductTokens
//     - selectPaymentMethod, paymentMethods state, selectedPaymentMethod state
//     - transferSuccess, withdrawalSuccess
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/repositories/wallet_repository.dart';

part 'wallet_provider.freezed.dart';

@freezed
abstract class WalletState with _$WalletState {
  const factory WalletState({
    @Default(false) bool isLoading,
    WalletBalance? balance,
    @Default([]) List<SubscriptionPackage> packages,
    List<SubscriptionPurchase>? purchases,
    @Default(1) int currentPage,
    @Default(false) bool hasMore,
    String? errorMessage,
    @Default(false) bool isPurchasingSubscription,
    @Default(false) bool isConfirmingPayment,
    SubscriptionPurchase? pendingPurchase,
    String? selectedPackageId,
  }) = _WalletState;
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _walletRepository;

  WalletNotifier(this._walletRepository) : super(const WalletState());

  Future<void> loadWalletData() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Parallel fetch: balance + packages catalog + recent purchases.
      final results = await Future.wait([
        _walletRepository.getWalletBalance(),
        _walletRepository.getSubscriptionPackages(),
        _walletRepository.getSubscriptionPurchases(limit: 10),
      ], eagerError: true);

      final balance = results[0] as WalletBalance;
      final packages = results[1] as List<SubscriptionPackage>;
      final purchases = results[2] as List<SubscriptionPurchase>;

      state = state.copyWith(
        isLoading: false,
        balance: balance,
        packages: packages,
        purchases: purchases,
        hasMore: purchases.length >= 10,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load wallet data: ${e.toString()}',
      );
    }
  }

  Future<void> loadMorePurchases() async {
    if (state.isLoading || !state.hasMore) return;
    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoading: true);
    try {
      final more = await _walletRepository.getSubscriptionPurchases(
        limit: 10,
        offset: nextPage * 10,
      );
      final existing = state.purchases ?? const <SubscriptionPurchase>[];
      state = state.copyWith(
        isLoading: false,
        purchases: [...existing, ...more],
        currentPage: nextPage,
        hasMore: more.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load more purchases: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1);
    await loadWalletData();
  }

  /// Selects a package for the user to subscribe to. Topup screen drives this
  /// via tap on a package card; Subscribe button reads state.selectedPackageId.
  void selectPackage(String packageId) {
    state = state.copyWith(selectedPackageId: packageId);
  }

  /// POST /wallet/purchase-subscription. Phone defaults to agent's registered
  /// number server-side (Q8); caller may override.
  Future<void> purchaseSubscription({
    required String packageId,
    String? phoneNumber,
  }) async {
    if (state.isPurchasingSubscription) return;
    state = state.copyWith(
      isPurchasingSubscription: true,
      errorMessage: null,
      pendingPurchase: null,
    );
    try {
      final request = SubscriptionPurchaseRequest(
        packageId: packageId,
        phoneNumber: phoneNumber,
      );
      final response = await _walletRepository.purchaseSubscription(request);

      // W1 backend returns: {purchaseId, packageName, amount, stkPhone, status}.
      // Refresh purchases list so the new PENDING row appears in state.
      final purchases =
          await _walletRepository.getSubscriptionPurchases(limit: 10);

      // Find the just-created purchase by id for the pendingPurchase pointer.
      SubscriptionPurchase? pending;
      final newId = response['purchaseId']?.toString();
      if (newId != null) {
        for (final p in purchases) {
          if (p.id == newId) {
            pending = p;
            break;
          }
        }
      }

      state = state.copyWith(
        isPurchasingSubscription: false,
        purchases: purchases,
        hasMore: purchases.length >= 10,
        pendingPurchase: pending,
      );
    } catch (e) {
      state = state.copyWith(
        isPurchasingSubscription: false,
        errorMessage: 'Subscription purchase failed: ${e.toString()}',
      );
    }
  }

  /// POST /wallet/confirm/:purchaseId — manual fallback for flaky STK callbacks.
  /// Topup screen exposes this behind an "I have paid" button (Q8b path ii).
  Future<void> confirmPayment(String purchaseId) async {
    if (state.isConfirmingPayment) return;
    state = state.copyWith(isConfirmingPayment: true, errorMessage: null);
    try {
      final confirmation = await _walletRepository.confirmPayment(purchaseId);

      // If confirmation succeeded, refresh balance to pick up the new plan.
      if (confirmation.status == 'SUCCESS') {
        final balance = await _walletRepository.getWalletBalance();
        final purchases =
            await _walletRepository.getSubscriptionPurchases(limit: 10);
        state = state.copyWith(
          isConfirmingPayment: false,
          balance: balance,
          purchases: purchases,
          pendingPurchase: null,
        );
      } else {
        // Just refresh the purchases list so the row's status updates.
        final purchases =
            await _walletRepository.getSubscriptionPurchases(limit: 10);
        state = state.copyWith(
          isConfirmingPayment: false,
          purchases: purchases,
          pendingPurchase: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isConfirmingPayment: false,
        errorMessage: 'Failed to confirm payment: ${e.toString()}',
      );
    }
  }

  /// Look up a package by id (for UI rendering when only the id is in scope).
  SubscriptionPackage? findPackageById(String id) {
    for (final p in state.packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final walletNotifierProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepository);
});