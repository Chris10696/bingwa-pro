// lib/features/wallet/presentation/providers/wallet_provider.dart
// W2: added coupon redemption, STK polling (subscribeAndPoll), and
// processing-mode setter. State extended with couponResult, couponError,
// isRedeemingCoupon, pollingStatus, lastCheckoutRequestId. Existing
// purchase/confirm flow retained; purchaseSubscription now captures the
// checkoutRequestId for polling.
//
// W3.I: WalletNotifier now also mirrors the agent's processing mode into the
// native SessionBridge so the on-device USSD engine (UssdExecutionService /
// UssdAccessibilityService) learns it without a Flutter engine or network call.
//   - loadWalletData mirrors the wallet's mode on every load (login/refresh).
//   - setProcessingMode is optimistic (instant radio flip), PATCHes the wallet,
//     re-mirrors the server-confirmed value, and reverts both local state and
//     the native mirror on failure.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/models/coupon_model.dart';
import '../../../../shared/repositories/wallet_repository.dart';
import '../../../../core/services/session_bridge_service.dart';
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
  final SessionBridgeService _sessionBridge;
  Timer? _pollTimer;
  WalletNotifier(this._walletRepository, this._sessionBridge)
      : super(const WalletState());

  /// Wire value for the backend + native bridge ('express' | 'advanced').
  /// The enum's Dart names already equal the wire strings, but this keeps the
  /// mapping explicit at every call site.
  String _wire(ProcessingMode mode) =>
      mode == ProcessingMode.express ? 'express' : 'advanced';

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
      // W3.I: mirror the wallet's processing mode to native on every load, so the
      // USSD engine tracks it from login/refresh onward (not just on radio change).
      final mode = balance.wallet?.processingMode ?? ProcessingMode.express;
      await _sessionBridge.saveProcessingMode(_wire(mode));
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
  /// W2.G + W3.I: persist processing mode ('express' | 'advanced') AND mirror it
  /// to the native bridge so the USSD engine picks it up.
  ///
  /// W3.I: optimistic — the local balance flips immediately so the radio responds
  /// instantly (matching Hybrid's instant-write feel), then we PATCH the wallet
  /// and re-mirror from the server's confirmed value. On failure we revert both
  /// the local state and the native mirror.
  Future<void> setProcessingMode(ProcessingMode mode) async {
    final previousBalance = state.balance;
    final previousMode =
        previousBalance?.wallet?.processingMode ?? ProcessingMode.express;

    // Optimistic local flip + immediate native mirror.
    state = state.copyWith(balance: _balanceWithMode(previousBalance, mode));
    await _sessionBridge.saveProcessingMode(_wire(mode));

    try {
      await _walletRepository.setProcessingMode(_wire(mode));
      // Confirm against server truth and re-mirror in case it normalised.
      final balance = await _walletRepository.getWalletBalance();
      state = state.copyWith(balance: balance);
      final confirmed = balance.wallet?.processingMode ?? mode;
      await _sessionBridge.saveProcessingMode(_wire(confirmed));
    } catch (e) {
      // Revert optimistic flip + native mirror.
      state = state.copyWith(
        balance: previousBalance,
        errorMessage: 'Failed to set processing mode: ${e.toString()}',
      );
      await _sessionBridge.saveProcessingMode(_wire(previousMode));
    }
  }

  /// Returns a copy of [balance] with the wallet's processingMode set to [mode].
  /// Null-safe: if there's no balance/wallet yet, returns the input unchanged.
  WalletBalance? _balanceWithMode(WalletBalance? balance, ProcessingMode mode) {
    if (balance == null) return null;
    final wallet = balance.wallet;
    if (wallet == null) return balance;
    return balance.copyWith(wallet: wallet.copyWith(processingMode: mode));
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
  final sessionBridge = ref.watch(sessionBridgeServiceProvider);
  return WalletNotifier(walletRepository, sessionBridge);
});