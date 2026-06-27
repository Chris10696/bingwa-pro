// lib/shared/repositories/offer_repository.dart
// W2: reshaped to new Offer fields. categoryId→type, ussdTemplate→ussdCode,
// dropped validityLabel + client agentId (JWT-derived). getCategories() removed.
// W3.H: updateOffer extended with the 7 Offer Settings fields (retry/reschedule/
// timeout) so the Offer Settings screen can partial-PATCH them. relayDevice is
// intentionally NOT exposed (W5).
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/offer_model.dart';
class OfferRepository {
  final Dio _dio;
  OfferRepository(this._dio);
  /// GET /offers — agent-scoped (backend filters by JWT).
  Future<List<Offer>> getOffers({
    OfferType? type,
    bool? isActiveOnly,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (type != null) params['type'] = type.toBackendValue();
      if (isActiveOnly != null) params['isActive'] = isActiveOnly;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      final response = await _dio.get(ApiConstants.offers, queryParameters: params);
      final list = (response.data['offers'] as List<dynamic>?) ?? const [];
      return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      AppLogger.e('Get offers failed:', e);
      rethrow;
    }
  }
  Future<Offer> getOfferById(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.offers}/$id');
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Get offer by id failed:', e);
      rethrow;
    }
  }
  /// POST /offers — agentId derived from JWT server-side.
  Future<Offer> createOffer({
    required String name,
    required String ussdCode,
    required int price,
    required OfferType type,
    bool? isActive,
    double? commissionRate,
    OfferProcessingMode? processingMode,
  }) async {
    try {
      final body = {
        'name': name,
        'ussdCode': ussdCode,
        'price': price,
        'type': type.toBackendValue(),
        if (isActive != null) 'isActive': isActive,
        if (commissionRate != null) 'commissionRate': commissionRate,
        // null = "use global default" → omit so the column stays null.
        if (processingMode != null)
          'processingMode': processingMode.toBackendValue(),
      };
      final response = await _dio.post(ApiConstants.offers, data: body);
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Create offer failed:', e);
      rethrow;
    }
  }

  /// PATCH /offers/:id — partial update; also used for toggle-active and (W3.H)
  /// for the Offer Settings fields. Only non-null params are sent, so each
  /// settings change can patch a single field (Hybrid auto-saves per change).
  ///
  /// W3.H note: [ussdTimeoutMillis] is the already-converted value (the Offer
  /// Settings screen multiplies its seconds stepper by 1000 before calling).
  /// [relayDevice] is intentionally absent (W5).
  Future<Offer> updateOffer(
    String id, {
    String? name,
    String? ussdCode,
    int? price,
    OfferType? type,
    bool? isActive,
    double? commissionRate,
    // W3.H Offer Settings fields:
    bool? autoReschedule,
    String? autoRescheduleRunTime,
    bool? autoRetry,
    bool? autoRetryConnectionProblems,
    int? numberOfRetries,
    int? retryIntervalMins,
    int? ussdTimeoutMillis,
    // Per-offer dial mode. setProcessingMode=true sends it (incl. null to clear → use
    // global); the partial toggle-active path leaves it false so the mode isn't touched.
    OfferProcessingMode? processingMode,
    bool setProcessingMode = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (ussdCode != null) body['ussdCode'] = ussdCode;
      if (price != null) body['price'] = price;
      if (type != null) body['type'] = type.toBackendValue();
      if (isActive != null) body['isActive'] = isActive;
      if (commissionRate != null) body['commissionRate'] = commissionRate;
      if (autoReschedule != null) body['autoReschedule'] = autoReschedule;
      if (autoRescheduleRunTime != null) {
        body['autoRescheduleRunTime'] = autoRescheduleRunTime;
      }
      if (autoRetry != null) body['autoRetry'] = autoRetry;
      if (autoRetryConnectionProblems != null) {
        body['autoRetryConnectionProblems'] = autoRetryConnectionProblems;
      }
      if (numberOfRetries != null) body['numberOfRetries'] = numberOfRetries;
      if (retryIntervalMins != null) body['retryIntervalMins'] = retryIntervalMins;
      if (ussdTimeoutMillis != null) body['ussdTimeoutMillis'] = ussdTimeoutMillis;
      if (setProcessingMode) {
        body['processingMode'] = processingMode?.toBackendValue();
      }
      final response = await _dio.patch('${ApiConstants.offers}/$id', data: body);
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Update offer failed:', e);
      rethrow;
    }
  }
  Future<Offer> toggleActive(String id, bool isActive) =>
      updateOffer(id, isActive: isActive);
  Future<void> deleteOffer(String id) async {
    try {
      await _dio.delete('${ApiConstants.offers}/$id');
    } on DioException catch (e) {
      AppLogger.e('Delete offer failed:', e);
      rethrow;
    }
  }
}
final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return OfferRepository(dio);
});