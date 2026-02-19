import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final Dio _dio;
  
  TransactionRepository(this._dio);
  
  // Execute Airtime Transaction
  Future<TransactionResponse> executeAirtime(TransactionRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.airtime,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.airtime,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.airtime,
        data: response.data,
      );
      
      final transactionResponse = TransactionResponse.fromJson(response.data);
      
      AppLogger.logTransaction(
        type: 'Airtime',
        phone: request.customerPhone,
        amount: request.amount,
        status: transactionResponse.status.name,
        reference: transactionResponse.reference,
      );
      
      return transactionResponse;
    } on DioException catch (e) {
      AppLogger.e('Airtime transaction failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Airtime transaction error:', e);
      rethrow;
    }
  }
  
  // Execute Data Transaction
  Future<TransactionResponse> executeData(TransactionRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.data,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.data,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.data,
        data: response.data,
      );
      
      final transactionResponse = TransactionResponse.fromJson(response.data);
      
      AppLogger.logTransaction(
        type: 'Data',
        phone: request.customerPhone,
        amount: request.amount,
        status: transactionResponse.status.name,
        reference: transactionResponse.reference,
      );
      
      return transactionResponse;
    } on DioException catch (e) {
      AppLogger.e('Data transaction failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Data transaction error:', e);
      rethrow;
    }
  }
  
  // Execute SMS Transaction
  Future<TransactionResponse> executeSms(TransactionRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.sms,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        ApiConstants.sms,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.sms,
        data: response.data,
      );
      
      final transactionResponse = TransactionResponse.fromJson(response.data);
      
      AppLogger.logTransaction(
        type: 'SMS',
        phone: request.customerPhone,
        amount: request.amount,
        status: transactionResponse.status.name,
        reference: transactionResponse.reference,
      );
      
      return transactionResponse;
    } on DioException catch (e) {
      AppLogger.e('SMS transaction failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('SMS transaction error:', e);
      rethrow;
    }
  }
  
  // Get Transaction Status
  Future<TransactionResponse> getTransactionStatus(String transactionId) async {
    try {
      final url = ApiConstants.transactionStatus.replaceFirst('{id}', transactionId);
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: url,
      );
      
      final response = await _dio.get(url);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      
      return TransactionResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get transaction status failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction status error:', e);
      rethrow;
    }
  }
  
  // Get Transaction History
  Future<TransactionListResponse> getTransactionHistory(TransactionFilter filter) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.transactionHistory,
        data: filter.toJson(),
      );
      
      final response = await _dio.get(
        ApiConstants.transactionHistory,
        queryParameters: filter.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.transactionHistory,
        data: response.data,
      );
      
      return TransactionListResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get transaction history failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction history error:', e);
      rethrow;
    }
  }
  
  // Retry Transaction
  Future<TransactionResponse> retryTransaction(RetryRequest request) async {
    try {
      final url = ApiConstants.retryTransaction.replaceFirst('{id}', request.transactionId);
      
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: url,
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        url,
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      
      final transactionResponse = TransactionResponse.fromJson(response.data);
      
      AppLogger.logTransaction(
        type: 'Retry',
        phone: 'N/A',
        amount: 0,
        status: transactionResponse.status.name,
        reference: transactionResponse.reference,
      );
      
      return transactionResponse;
    } on DioException catch (e) {
      AppLogger.e('Retry transaction failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Retry transaction error:', e);
      rethrow;
    }
  }
  
  // Get USSD Health Status
  Future<UssdHealthCheck> getUssdHealthStatus() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.ussdHealth,
      );
      
      final response = await _dio.get(ApiConstants.ussdHealth);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.ussdHealth,
        data: response.data,
      );
      
      return UssdHealthCheck.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get USSD health failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get USSD health error:', e);
      rethrow;
    }
  }
  
  // Get USSD Codes
  Future<List<ProductBundle>> getUssdCodes() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.ussdCodes,
      );
      
      final response = await _dio.get(ApiConstants.ussdCodes);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.ussdCodes,
        data: response.data,
      );
      
      final bundles = (response.data['bundles'] as List)
          .map((json) => ProductBundle.fromJson(json))
          .toList();
      
      return bundles;
    } on DioException catch (e) {
      AppLogger.e('Get USSD codes failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get USSD codes error:', e);
      rethrow;
    }
  }
  
  // Get Safaricom Bundles
  Future<List<ProductBundle>> getSafaricomBundles() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.safaricomBundles,
      );
      
      final response = await _dio.get(ApiConstants.safaricomBundles);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.safaricomBundles,
        data: response.data,
      );
      
      final bundles = (response.data['bundles'] as List)
          .map((json) => ProductBundle.fromJson(json))
          .toList();
      
      return bundles;
    } on DioException catch (e) {
      AppLogger.e('Get Safaricom bundles failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get Safaricom bundles error:', e);
      rethrow;
    }
  }
  
  // Get Products
  Future<List<ProductBundle>> getProducts({
    TransactionType? type,
    String? network,
    bool? activeOnly,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (type != null) params['type'] = type.name;
      if (network != null) params['network'] = network;
      if (activeOnly != null) params['active_only'] = activeOnly;
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.products,
        data: params,
      );
      
      final response = await _dio.get(
        ApiConstants.products,
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.products,
        data: response.data,
      );
      
      final bundles = (response.data['products'] as List)
          .map((json) => ProductBundle.fromJson(json))
          .toList();
      
      return bundles;
    } on DioException catch (e) {
      AppLogger.e('Get products failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get products error:', e);
      rethrow;
    }
  }
  
  // Get Transaction Details
  Future<TransactionDetails> getTransactionDetails(String transactionId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/transactions/$transactionId/details',
      );
      
      final response = await _dio.get('/transactions/$transactionId/details');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/transactions/$transactionId/details',
        data: response.data,
      );
      
      return TransactionDetails.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get transaction details failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction details error:', e);
      rethrow;
    }
  }
  
  // Get Transaction Summary
  Future<TransactionSummary> getTransactionSummary(String period) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/transactions/summary/$period',
      );
      
      final response = await _dio.get('/transactions/summary/$period');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/transactions/summary/$period',
        data: response.data,
      );
      
      return TransactionSummary.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get transaction summary failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction summary error:', e);
      rethrow;
    }
  }
  
  // Report Transaction Issue
  Future<void> reportTransactionIssue({
    required String transactionId,
    required String issueType,
    required String description,
    List<String>? attachments,
  }) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/transactions/$transactionId/report',
        data: {
          'issue_type': issueType,
          'description': description,
          if (attachments != null) 'attachments': attachments,
        },
      );
      
      final response = await _dio.post(
        '/transactions/$transactionId/report',
        data: {
          'issue_type': issueType,
          'description': description,
          if (attachments != null) 'attachments': attachments,
        },
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/transactions/$transactionId/report',
        data: response.data,
      );
      
      AppLogger.logSessionEvent(
        event: 'Transaction issue reported',
        details: 'Transaction: $transactionId, Issue: $issueType',
      );
    } on DioException catch (e) {
      AppLogger.e('Report transaction issue failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Report transaction issue error:', e);
      rethrow;
    }
  }
}

// Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return TransactionRepository(dio);
});