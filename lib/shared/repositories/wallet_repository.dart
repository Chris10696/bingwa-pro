// lib/shared/repositories/wallet_repository.dart
// W1: stripped to retained methods per primer.
//   KEEP: getWalletBalance, initiateMpesaPayment, confirmPayment
//   RENAME: purchaseTokens → purchaseSubscription
//           getWalletTransactions → getSubscriptionPurchases
//   ADD:    getActivePlans, getSubscriptionPackages
//   DELETE: transferTokens, withdrawTokens, getWalletSummary, getPaymentMethods,
//           initiateAirtimePayment, checkTransactionStatus, cancelTransaction,
//           getTransactionReceipt, checkForPayments, deductTokens,
//           updatePaymentSettings
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/wallet_model.dart';
import '../models/subscription_package_model.dart';
import '../models/subscription_plan_model.dart';

class WalletRepository {
  final Dio _dio;
  WalletRepository(this._dio);

  /// GET /wallet/balance — returns composite payload:
  ///   { hasUsableTokens, plans, wallet: {processingMode, isProcessing,
  ///     lifetimeTokensPurchased, lifetimeTokensConsumed} }
  Future<WalletBalance> getWalletBalance() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.walletBalance,
      );
      final response = await _dio.get(ApiConstants.walletBalance);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.walletBalance,
        data: response.data,
      );
      return WalletBalance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Get wallet balance failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get wallet balance error:', e);
      rethrow;
    }
  }

  /// GET /subscriptions/plans/me — active plans for the logged-in agent.
  /// Mostly used by the dashboard's plan-status readout; /wallet/balance
  /// already returns plans inline, but this is the canonical direct fetch.
  Future<List<SubscriptionPlan>> getActivePlans() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.subscriptionPlansMe,
      );
      final response = await _dio.get(ApiConstants.subscriptionPlansMe);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.subscriptionPlansMe,
        data: response.data,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.e('Get active plans failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get active plans error:', e);
      rethrow;
    }
  }

  /// GET /subscriptions/packages — full package catalog.
  Future<List<SubscriptionPackage>> getSubscriptionPackages({
    bool includeInactive = false,
  }) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.subscriptionPackages,
      );
      final response = await _dio.get(
        ApiConstants.subscriptionPackages,
        queryParameters: {
          if (includeInactive) 'includeInactive': 'true',
        },
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.subscriptionPackages,
        data: response.data,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.e('Get subscription packages failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get subscription packages error:', e);
      rethrow;
    }
  }

  /// POST /wallet/purchase-subscription — initiates STK push for a package.
  /// W1 backend is stubbed and returns a PENDING purchase record; W2 wires
  /// in real M-Pesa initiation.
  Future<Map<String, dynamic>> purchaseSubscription(
    SubscriptionPurchaseRequest request,
  ) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.purchaseSubscription,
        data: request.toJson(),
      );
      final response = await _dio.post(
        ApiConstants.purchaseSubscription,
        data: request.toJson(),
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.purchaseSubscription,
        data: response.data,
      );
      AppLogger.logTransaction(
        type: 'Subscription Purchase',
        phone: request.phoneNumber ?? 'Self',
        amount: 0, // amount comes from server-side package price
        status: 'PENDING',
        reference: response.data['purchaseId']?.toString() ?? '',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      AppLogger.e('Subscription purchase failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Subscription purchase error:', e);
      rethrow;
    }
  }

  /// GET /wallet/purchases — past subscription purchases (audit).
  Future<List<SubscriptionPurchase>> getSubscriptionPurchases({
    int? limit,
    int? offset,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (limit != null) params['limit'] = limit;
      if (offset != null) params['offset'] = offset;
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.walletPurchases,
        data: params,
      );
      final response = await _dio.get(
        ApiConstants.walletPurchases,
        queryParameters: params,
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.walletPurchases,
        data: response.data,
      );
      final list = (response.data['purchases'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => SubscriptionPurchase.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.e('Get subscription purchases failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get subscription purchases error:', e);
      rethrow;
    }
  }

  /// POST /wallet/mpesa/initiate — initiate M-Pesa STK push directly.
  /// Used as an alternative to purchaseSubscription for ad-hoc flows;
  /// W2 may consolidate them.
  Future<Map<String, dynamic>> initiateMpesaPayment({
    required String phoneNumber,
    required double amount,
    required String reference,
    String? description,
  }) async {
    try {
      final body = {
        'phoneNumber': phoneNumber,
        'amount': amount,
        'reference': reference,
        if (description != null) 'description': description,
      };
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.initiateMpesa,
        data: body,
      );
      final response = await _dio.post(
        ApiConstants.initiateMpesa,
        data: body,
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.initiateMpesa,
        data: response.data,
      );
      AppLogger.logTransaction(
        type: 'M-Pesa Initiated',
        phone: phoneNumber,
        amount: amount,
        status: 'PENDING',
        reference: reference,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      AppLogger.e('M-Pesa initiation failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('M-Pesa initiation error:', e);
      rethrow;
    }
  }

  /// POST /wallet/confirm/:transactionId — manual fallback for users who
  /// completed the STK PIN flow but the Daraja callback hasn't arrived.
  Future<PaymentConfirmation> confirmPayment(String transactionId) async {
    try {
      final url = '${ApiConstants.confirmPayment}/$transactionId';
      AppLogger.logNetworkRequest(method: 'POST', url: url);
      final response = await _dio.post(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      final confirmation = PaymentConfirmation.fromJson(
        response.data as Map<String, dynamic>,
      );
      AppLogger.logTransaction(
        type: 'Payment Confirmed',
        phone: confirmation.phoneNumber ?? 'N/A',
        amount: confirmation.amount ?? 0,
        status: confirmation.status,
        reference: confirmation.reference,
      );
      return confirmation;
    } on DioException catch (e) {
      AppLogger.e('Payment confirmation failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Payment confirmation error:', e);
      rethrow;
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return WalletRepository(dio);
});