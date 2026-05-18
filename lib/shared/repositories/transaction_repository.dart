// lib/shared/repositories/transaction_repository.dart
// W1: stripped of product/execute methods per primer.
//   DELETE: executeAirtime, executeData, executeSms, getProducts,
//           getUssdCodes, getSafaricomBundles, findProductByPrice
//   KEEP:   getTransactionStatus, getTransactionHistory, retryTransaction,
//           getUssdHealthStatus (Q3 default), getTransactionDetails,
//           getTransactionSummary, reportTransactionIssue
// Their unified replacement executeOffer(offerId, customerPhone) ships in W2.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final Dio _dio;
  TransactionRepository(this._dio);

  Future<TransactionResponse> getTransactionStatus(String transactionId) async {
    try {
      final url = ApiConstants.transactionStatus.replaceFirst(
        '{id}',
        transactionId,
      );
      AppLogger.logNetworkRequest(method: 'GET', url: url);
      final response = await _dio.get(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      return TransactionResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.e('Get transaction status failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction status error:', e);
      rethrow;
    }
  }

  Future<TransactionListResponse> getTransactionHistory(
    TransactionFilter filter,
  ) async {
    try {
      final queryParams = filter.toJson();
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.transactionHistory,
        queryParameters: queryParams,
        data: filter.toJson(),
      );
      final response = await _dio.get(
        ApiConstants.transactionHistory,
        queryParameters: queryParams,
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.transactionHistory,
        data: response.data,
      );
      return TransactionListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.e('Get transaction history failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction history error:', e);
      rethrow;
    }
  }

  Future<TransactionResponse> retryTransaction(RetryRequest request) async {
    try {
      final url = ApiConstants.retryTransaction.replaceFirst(
        '{id}',
        request.transactionId,
      );
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: url,
        data: request.toJson(),
      );
      final response = await _dio.post(url, data: request.toJson());
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      final transactionResponse = TransactionResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      AppLogger.logTransaction(
        type: 'Retry',
        phone: 'N/A',
        amount: transactionResponse.amount,
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

  // Q3 default: kept intact even though no W1 caller remains.
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
      return UssdHealthCheck.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Get USSD health failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get USSD health error:', e);
      rethrow;
    }
  }

  Future<TransactionDetails> getTransactionDetails(String transactionId) async {
    try {
      final url = '/transactions/$transactionId/details';
      AppLogger.logNetworkRequest(method: 'GET', url: url);
      final response = await _dio.get(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      return TransactionDetails.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.e('Get transaction details failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction details error:', e);
      rethrow;
    }
  }

  Future<TransactionSummary> getTransactionSummary(String period) async {
    try {
      final url = '/transactions/summary/$period';
      AppLogger.logNetworkRequest(method: 'GET', url: url);
      final response = await _dio.get(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      return TransactionSummary.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.e('Get transaction summary failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get transaction summary error:', e);
      rethrow;
    }
  }

  Future<void> reportTransactionIssue({
    required String transactionId,
    required String issueType,
    required String description,
    List<String>? attachments,
  }) async {
    try {
      final url = '/transactions/$transactionId/report';
      final body = {
        'issue_type': issueType,
        'description': description,
        if (attachments != null) 'attachments': attachments,
      };
      AppLogger.logNetworkRequest(method: 'POST', url: url, data: body);
      final response = await _dio.post(url, data: body);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
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

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return TransactionRepository(dio);
});