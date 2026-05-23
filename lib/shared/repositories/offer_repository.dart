// lib/shared/repositories/offer_repository.dart
// W2: reshaped to new Offer fields. categoryId→type, ussdTemplate→ussdCode,
// dropped validityLabel + client agentId (JWT-derived). getCategories() removed.
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
  }) async {
    try {
      final body = {
        'name': name,
        'ussdCode': ussdCode,
        'price': price,
        'type': type.toBackendValue(),
        if (isActive != null) 'isActive': isActive,
      };
      final response = await _dio.post(ApiConstants.offers, data: body);
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Create offer failed:', e);
      rethrow;
    }
  }

  /// PATCH /offers/:id — partial update; also used for toggle-active.
  Future<Offer> updateOffer(
    String id, {
    String? name,
    String? ussdCode,
    int? price,
    OfferType? type,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (ussdCode != null) body['ussdCode'] = ussdCode;
      if (price != null) body['price'] = price;
      if (type != null) body['type'] = type.toBackendValue();
      if (isActive != null) body['isActive'] = isActive;
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