import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/wallet_model.dart';

class WalletRepository {
  final Dio _dio;
  
  WalletRepository(this._dio);
  
  // Get Wallet Balance
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
      
      return WalletBalance.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get wallet balance failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get wallet balance error:', e);
      rethrow;
    }
  }
  
  // Get Wallet Transactions
  Future<List<WalletTransaction>> getWalletTransactions({
    int? limit,
    int? offset,
    WalletTransactionType? type,
    WalletTransactionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (limit != null) params['limit'] = limit;
      if (offset != null) params['offset'] = offset;
      if (type != null) params['type'] = type.name;
      if (status != null) params['status'] = status.name;
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.walletTransactions,
        data: params,
      );
      
      final response = await _dio.get(
        ApiConstants.walletTransactions,
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.walletTransactions,
        data: response.data,
      );
      
      final transactions = (response.data['transactions'] as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
      
      return transactions;
    } on DioException catch (e) {
      AppLogger.e('Get wallet transactions failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get wallet transactions error:', e);
      rethrow;
    }
  }
  
  // Purchase Tokens
  Future<WalletTransaction> purchaseTokens(TokenPurchaseRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.purchaseTokens,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.purchaseTokens,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.purchaseTokens,
        data: response.data,
      );
      
      final transaction = WalletTransaction.fromJson(response.data);
      
      AppLogger.logTransaction(
        type: 'Token Purchase',
        phone: 'Self',
        amount: request.amount,
        status: transaction.status.name,
        reference: transaction.reference,
      );
      
      return transaction;
    } on DioException catch (e) {
      AppLogger.e('Token purchase failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Token purchase error:', e);
      rethrow;
    }
  }
  
  // Initiate M-Pesa Payment
  Future<Map<String, dynamic>> initiateMpesaPayment(MpesaPaymentRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.initiateMpesa,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.initiateMpesa,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.initiateMpesa,
        data: response.data,
      );
      
      AppLogger.logTransaction(
        type: 'M-Pesa Initiated',
        phone: request.phoneNumber,
        amount: request.amount,
        status: 'PENDING',
        reference: request.reference,
      );
      
      return response.data;
    } on DioException catch (e) {
      AppLogger.e('M-Pesa initiation failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('M-Pesa initiation error:', e);
      rethrow;
    }
  }
  
  // Confirm Payment
  Future<PaymentConfirmation> confirmPayment(String transactionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '${ApiConstants.confirmPayment}/$transactionId',
      );
      
      final response = await _dio.post(
        '${ApiConstants.confirmPayment}/$transactionId',
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '${ApiConstants.confirmPayment}/$transactionId',
        data: response.data,
      );
      
      final confirmation = PaymentConfirmation.fromJson(response.data);
      
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
  
  // Get Wallet Summary
  Future<WalletSummary> getWalletSummary() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/wallet/summary',
      );
      
      final response = await _dio.get('/wallet/summary');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/summary',
        data: response.data,
      );
      
      return WalletSummary.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get wallet summary failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get wallet summary error:', e);
      rethrow;
    }
  }
  
  // Get Payment Methods
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/wallet/payment-methods',
      );
      
      final response = await _dio.get('/wallet/payment-methods');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/payment-methods',
        data: response.data,
      );
      
      final methods = (response.data['methods'] as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
      
      return methods;
    } on DioException catch (e) {
      AppLogger.e('Get payment methods failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get payment methods error:', e);
      rethrow;
    }
  }
  
  // Initiate Airtime Payment
  Future<Map<String, dynamic>> initiateAirtimePayment(AirtimePaymentRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/wallet/airtime/initiate',
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        '/wallet/airtime/initiate',
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/airtime/initiate',
        data: response.data,
      );
      
      AppLogger.logTransaction(
        type: 'Airtime Payment Initiated',
        phone: request.phoneNumber,
        amount: request.amount,
        status: 'PENDING',
        reference: request.reference,
      );
      
      return response.data;
    } on DioException catch (e) {
      AppLogger.e('Airtime payment initiation failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Airtime payment initiation error:', e);
      rethrow;
    }
  }
  
  // Check Transaction Status
  Future<WalletTransaction> checkTransactionStatus(String transactionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/wallet/transactions/$transactionId/status',
      );
      
      final response = await _dio.get('/wallet/transactions/$transactionId/status');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/transactions/$transactionId/status',
        data: response.data,
      );
      
      return WalletTransaction.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Check transaction status failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Check transaction status error:', e);
      rethrow;
    }
  }
  
  // Cancel Pending Transaction
  Future<void> cancelTransaction(String transactionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/wallet/transactions/$transactionId/cancel',
      );
      
      final response = await _dio.post('/wallet/transactions/$transactionId/cancel');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/transactions/$transactionId/cancel',
        data: response.data,
      );
      
      AppLogger.logTransaction(
        type: 'Transaction Cancelled',
        phone: 'N/A',
        amount: 0,
        status: 'CANCELLED',
        reference: transactionId,
      );
    } on DioException catch (e) {
      AppLogger.e('Cancel transaction failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Cancel transaction error:', e);
      rethrow;
    }
  }
  
  // Get Transaction Receipt
  Future<Map<String, dynamic>> getTransactionReceipt(String transactionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/wallet/transactions/$transactionId/receipt',
      );
      
      final response = await _dio.get('/wallet/transactions/$transactionId/receipt');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/wallet/transactions/$transactionId/receipt',
        data: response.data,
      );
      
      return response.data;
    } on DioException catch (e) {
      AppLogger.e('Get transaction receipt failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction receipt error:', e);
      rethrow;
    }
  }
}

// Provider
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return WalletRepository(dio);
});