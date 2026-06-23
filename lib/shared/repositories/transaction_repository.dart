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

  /// Lightweight status poll for the pay-with-airtime / quick-dial sheets.
  ///
  /// GET /transactions/:id/status returns a SLIM payload —
  /// {id, status, reference, errorMessage, ussdResponse} — NOT a full transaction.
  /// Routing that through [TransactionResponse.fromJson] throws
  /// `type 'Null' is not a subtype of type 'String' in type cast`, because the model's
  /// required fields (transactionId, timestamp, amount) are absent from the slim shape.
  /// That exception was being swallowed by the poll loop's `catch`, so the poll spun to
  /// its cap and never granted — airtime moved but no plan was granted.
  ///
  /// This reads only what a poll needs, tolerantly, so it never crashes on the slim shape.
  /// It returns the RAW backend status string (e.g. 'SUCCESS', 'FAILED', 'PROCESSING',
  /// 'FAILED_ALREADY_RECOMMENDED', 'BLOCKED') and the best available response text
  /// (ussdResponse, else errorMessage, else ''). A genuine network/transport error still
  /// throws (DioException) so the caller's retry loop can keep polling.
  Future<({String status, String responseText})> getTransactionStatusLite(
    String transactionId,
  ) async {
    final url = ApiConstants.transactionStatus.replaceFirst(
      '{id}',
      transactionId,
    );
    AppLogger.logNetworkRequest(method: 'GET', url: url);
    final response = await _dio.get(url);
    AppLogger.logNetworkResponse(
      statusCode: response.statusCode ?? 0,
      url: url,
      data: response.data,
    );
    final map = (response.data as Map).cast<String, dynamic>();
    final status = (map['status'] ?? '').toString();
    final ussd = (map['ussdResponse'] ?? '').toString();
    final err = (map['errorMessage'] ?? '').toString();
    return (
      status: status,
      responseText: ussd.trim().isNotEmpty ? ussd : err,
    );
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
      final url = '/transactions/$transactionId';
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

 // W2.D Quick Dial: POST /transactions. Returns the created transaction id +
// status. With dio validateStatus<500, a 402 (no usable tokens) resolves
// rather than throws — caller must inspect statusCode.
  Future<Response> createQuickDial({
    required String offerId,
    required String customerPhone,
  }) async {
    final body = {'offerId': offerId, 'customerPhone': customerPhone};
    AppLogger.logNetworkRequest(
      method: 'POST', url: ApiConstants.transactions, data: body);
    final response = await _dio.post(ApiConstants.transactions, data: body);
    AppLogger.logNetworkResponse(
      statusCode: response.statusCode ?? 0,
      url: ApiConstants.transactions, data: response.data);
    return response;
  }
  // Pay-with-airtime: POST /transactions/airtime-subscription. Creates the
  // SUBSCRIPTION_RENEWAL Sambaza transaction (no token debit). validateStatus<500,
  // so a non-2xx resolves — caller inspects statusCode.
  Future<Response> createAirtimeSubscription({required String packageId}) async {
    final body = {'packageId': packageId};
    final url = '${ApiConstants.transactions}/airtime-subscription';
    AppLogger.logNetworkRequest(method: 'POST', url: url, data: body);
    final response = await _dio.post(url, data: body);
    AppLogger.logNetworkResponse(
        statusCode: response.statusCode ?? 0, url: url, data: response.data);
    return response;
  }
  // W2.F: GET /transactions/scheduled. amount is a Postgres decimal → arrives
  // as either a number (50) or a string ("49.00"); parse tolerantly.
  Future<List<ScheduledTransaction>> getScheduled() async {
    final response = await _dio.get(ApiConstants.scheduledTransactions);
    final list = (response.data['scheduled'] as List<dynamic>?) ?? const [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return ScheduledTransaction(
        id: m['id'] as String,
        agentId: m['agentId'] as String,
        offerId: m['offerId'] as String?,
        offerName: m['offerName'] as String?,
        customerPhone: m['customerPhone'] as String? ?? '',
        amount: _toDouble(m['amount']),
        rescheduleInfo: m['rescheduleInfo'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
    }).toList();
  }
  // Tolerant numeric parse: backend decimals come as String, ints as num.
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
  // W2.F: POST /transactions/schedule.
  Future<ScheduledTransaction> schedule(ScheduleTransactionRequest req) async {
    final response =
        await _dio.post(ApiConstants.scheduleTransaction, data: req.toJson());
    final m = response.data as Map<String, dynamic>;
    return ScheduledTransaction(
      id: m['id'] as String,
      agentId: m['agentId'] as String,
      offerId: m['offerId'] as String?,
      offerName: m['offerName'] as String?,
      customerPhone: m['customerPhone'] as String? ?? '',
      amount: _toDouble(m['amount']),
      rescheduleInfo: m['rescheduleInfo'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(m['createdAt'] as String),
    );
  }
  // W2.F: DELETE /transactions/scheduled/:id.
  Future<void> cancelScheduled(String id) async {
    await _dio.delete('${ApiConstants.scheduledTransactions}/$id');
  }
}
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return TransactionRepository(dio);
});