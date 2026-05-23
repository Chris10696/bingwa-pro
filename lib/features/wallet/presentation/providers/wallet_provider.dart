// lib/features/wallet/presentation/providers/wallet_provider.dart
// W2: added coupon redemption, STK polling (subscribeAndPoll), and
// processing-mode setter. State extended with couponResult, couponError,
// isRedeemingCoupon, pollingStatus, lastCheckoutRequestId. Existing
// purchase/confirm flow retained; purchaseSubscription now captures the
// checkoutRequestId for polling.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/models/coupon_model.dart';
import '../../../../shared/repositories/wallet_repository.dart';

part 'wallet_provider.freezed.dart';

// Polling lifecycle for the STK flow.
enum StkPollStatus { idle, polling, success, failed, timeout }

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
    // W2 additions:
    String? lastCheckoutRequestId,
    @Default(StkPollStatus.idle) StkPollStatus pollStatus,
    @Default(false) bool isRedeemingCoupon,
    CouponRedemptionResult? couponResult,
    String? couponError,
  }) = _WalletState;
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _walletRepository;
  Timer? _pollTimer;

  WalletNotifier(this._walletRepository) : super(const WalletState());

  Future<void> loadWalletData() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
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

  void selectPackage(String packageId) {
    state = state.copyWith(selectedPackageId: packageId);
  }

  /// W2.B: initiate STK + poll /mpesa/status every 2s up to 60s. Resolves the
  /// pollStatus to success/failed/timeout. Grant happens server-side (single
  /// grant path); on success we refresh balance + purchases.
  Future<void> subscribeAndPoll({
    required String packageId,
    String? phoneNumber,
  }) async {
    if (state.isPurchasingSubscription) return;
    _pollTimer?.cancel();
    state = state.copyWith(
      isPurchasingSubscription: true,
      errorMessage: null,
      pendingPurchase: null,
      lastCheckoutRequestId: null,
      pollStatus: StkPollStatus.idle,
    );
    try {
      final request = SubscriptionPurchaseRequest(
        packageId: packageId,
        phoneNumber: phoneNumber,
      );
      final response = await _walletRepository.purchaseSubscription(request);
      final checkoutRequestId = response['checkoutRequestId']?.toString();

      // Refresh purchases so the new PENDING row appears.
      final purchases =
          await _walletRepository.getSubscriptionPurchases(limit: 10);
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
        lastCheckoutRequestId: checkoutRequestId,
        pollStatus:
            checkoutRequestId != null ? StkPollStatus.polling : StkPollStatus.idle,
      );

      if (checkoutRequestId != null) {
        _startPolling(checkoutRequestId);
      }
    } catch (e) {
      state = state.copyWith(
        isPurchasingSubscription: false,
        errorMessage: 'Subscription purchase failed: ${e.toString()}',
        pollStatus: StkPollStatus.failed,
      );
    }
  }

  void _startPolling(String checkoutRequestId) {
    const interval = Duration(seconds: 2);
    const maxAttempts = 30; // 30 × 2s = 60s
    int attempts = 0;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (timer) async {
      attempts++;
      try {
        final status =
            await _walletRepository.getMpesaStatus(checkoutRequestId);
        final s = (status['status']?.toString() ?? '').toUpperCase();

        if (s == 'COMPLETED') {
          timer.cancel();
          final balance = await _walletRepository.getWalletBalance();
          final purchases =
              await _walletRepository.getSubscriptionPurchases(limit: 10);
          state = state.copyWith(
            pollStatus: StkPollStatus.success,
            balance: balance,
            purchases: purchases,
            pendingPurchase: null,
          );
        } else if (s == 'FAILED') {
          timer.cancel();
          final purchases =
              await _walletRepository.getSubscriptionPurchases(limit: 10);
          state = state.copyWith(
            pollStatus: StkPollStatus.failed,
            purchases: purchases,
          );
        } else if (attempts >= maxAttempts) {
          timer.cancel();
          state = state.copyWith(pollStatus: StkPollStatus.timeout);
        }
        // else PENDING/INITIATED → keep polling.
      } catch (e) {
        if (attempts >= maxAttempts) {
          timer.cancel();
          state = state.copyWith(pollStatus: StkPollStatus.timeout);
        }
        // transient error mid-poll → keep trying until maxAttempts.
      }
    });
  }

  /// Legacy direct purchase (no polling) — kept for compatibility. Prefer
  /// subscribeAndPoll. Still used if a caller only wants to fire STK.
  Future<void> purchaseSubscription({
    required String packageId,
    String? phoneNumber,
  }) async {
    await subscribeAndPoll(packageId: packageId, phoneNumber: phoneNumber);
  }

  /// POST /wallet/confirm/:purchaseId — manual fallback.
  Future<void> confirmPayment(String purchaseId) async {
    if (state.isConfirmingPayment) return;
    state = state.copyWith(isConfirmingPayment: true, errorMessage: null);
    try {
      final confirmation = await _walletRepository.confirmPayment(purchaseId);
      if (confirmation.status == 'COMPLETED') {
        final balance = await _walletRepository.getWalletBalance();
        final purchases =
            await _walletRepository.getSubscriptionPurchases(limit: 10);
        state = state.copyWith(
          isConfirmingPayment: false,
          balance: balance,
          purchases: purchases,
          pendingPurchase: null,
          pollStatus: StkPollStatus.success,
        );
      } else {
        final purchases =
            await _walletRepository.getSubscriptionPurchases(limit: 10);
        state = state.copyWith(
          isConfirmingPayment: false,
          purchases: purchases,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isConfirmingPayment: false,
        errorMessage: 'Failed to confirm payment: ${e.toString()}',
      );
    }
  }

  /// W2.B: redeem a coupon. Inspects statusCode (dio validateStatus<500 means
  /// 400/404 resolve rather than throw). On 2xx, refreshes balance.
  Future<void> redeemCoupon(String code) async {
    if (state.isRedeemingCoupon) return;
    state = state.copyWith(
      isRedeemingCoupon: true,
      couponError: null,
      couponResult: null,
    );
    try {
      final response = await _walletRepository.redeemCoupon(code);
      final sc = response.statusCode ?? 0;
      if (sc >= 200 && sc < 300) {
        final result = CouponRedemptionResult.fromJson(
          response.data as Map<String, dynamic>,
        );
        final balance = await _walletRepository.getWalletBalance();
        state = state.copyWith(
          isRedeemingCoupon: false,
          couponResult: result,
          balance: balance,
        );
      } else {
        // Extract backend error message if present.
        String msg = 'Coupon could not be redeemed';
        final data = response.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        }
        state = state.copyWith(
          isRedeemingCoupon: false,
          couponError: msg,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isRedeemingCoupon: false,
        couponError: 'Failed to redeem coupon: ${e.toString()}',
      );
    }
  }

  void clearCouponState() {
    state = state.copyWith(couponResult: null, couponError: null);
  }

  /// W2.G: persist processing mode ('express' | 'advanced'). Refreshes balance
  /// so the wallet's processingMode reflects the change.
  Future<void> setProcessingMode(ProcessingMode mode) async {
    try {
      await _walletRepository.setProcessingMode(
        mode == ProcessingMode.express ? 'express' : 'advanced',
      );
      final balance = await _walletRepository.getWalletBalance();
      state = state.copyWith(balance: balance);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to set processing mode: ${e.toString()}',
      );
    }
  }

  SubscriptionPackage? findPackageById(String id) {
    for (final p in state.packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void resetPollStatus() {
    _pollTimer?.cancel();
    state = state.copyWith(pollStatus: StkPollStatus.idle);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final walletNotifierProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepository);
});