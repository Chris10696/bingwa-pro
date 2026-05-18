// lib/shared/repositories/offer_repository.dart
// W1 new repository. No UI consumer in W1; wired in W2 (Offers management +
// Quick Dial). All endpoints under /offers and /categories.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/offer_model.dart';
import '../models/offer_category_model.dart';

class OfferRepository {
  final Dio _dio;
  OfferRepository(this._dio);

  /// GET /offers — list offers with optional filters.
  Future<List<Offer>> getOffers({
    String? categoryId,
    bool? isActiveOnly,
    String? agentId,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (categoryId != null) params['categoryId'] = categoryId;
      if (isActiveOnly != null) params['isActive'] = isActiveOnly;
      if (agentId != null) params['agentId'] = agentId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;

      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.offers,
        queryParameters: params,
      );
      final response = await _dio.get(
        ApiConstants.offers,
        queryParameters: params,
      );
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.offers,
        data: response.data,
      );
      final list = (response.data['offers'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => Offer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.e('Get offers failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get offers error:', e);
      rethrow;
    }
  }

  /// GET /offers/:id
  Future<Offer> getOfferById(String id) async {
    try {
      final url = '${ApiConstants.offers}/$id';
      AppLogger.logNetworkRequest(method: 'GET', url: url);
      final response = await _dio.get(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Get offer by id failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get offer by id error:', e);
      rethrow;
    }
  }

  /// POST /offers
  Future<Offer> createOffer({
    required String name,
    required String ussdTemplate,
    required int price,
    required String validityLabel,
    required String categoryId,
    required String agentId,
    bool? isActive,
  }) async {
    try {
      final body = {
        'name': name,
        'ussdTemplate': ussdTemplate,
        'price': price,
        'validityLabel': validityLabel,
        'categoryId': categoryId,
        'agentId': agentId,
        if (isActive != null) 'isActive': isActive,
      };
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: ApiConstants.offers,
        data: body,
      );
      final response = await _dio.post(ApiConstants.offers, data: body);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.offers,
        data: response.data,
      );
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Create offer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Create offer error:', e);
      rethrow;
    }
  }

  /// PATCH /offers/:id — partial update. Pass only fields to change.
  /// Used by both full-field updates and toggle-active per Q10.
  Future<Offer> updateOffer(
    String id, {
    String? name,
    String? ussdTemplate,
    int? price,
    String? validityLabel,
    String? categoryId,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (ussdTemplate != null) body['ussdTemplate'] = ussdTemplate;
      if (price != null) body['price'] = price;
      if (validityLabel != null) body['validityLabel'] = validityLabel;
      if (categoryId != null) body['categoryId'] = categoryId;
      if (isActive != null) body['isActive'] = isActive;

      final url = '${ApiConstants.offers}/$id';
      AppLogger.logNetworkRequest(method: 'PATCH', url: url, data: body);
      final response = await _dio.patch(url, data: body);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
      return Offer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.e('Update offer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Update offer error:', e);
      rethrow;
    }
  }

  /// Convenience wrapper for the most common partial update — flip isActive.
  /// Calls the same PATCH endpoint per Q10.
  Future<Offer> toggleActive(String id, bool isActive) =>
      updateOffer(id, isActive: isActive);

  /// DELETE /offers/:id
  Future<void> deleteOffer(String id) async {
    try {
      final url = '${ApiConstants.offers}/$id';
      AppLogger.logNetworkRequest(method: 'DELETE', url: url);
      final response = await _dio.delete(url);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: url,
        data: response.data,
      );
    } on DioException catch (e) {
      AppLogger.e('Delete offer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Delete offer error:', e);
      rethrow;
    }
  }

  /// GET /categories — list the three seeded categories (Data, Minutes, SMS).
  Future<List<OfferCategory>> getCategories() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.categories,
      );
      final response = await _dio.get(ApiConstants.categories);
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.categories,
        data: response.data,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => OfferCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.e('Get categories failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get categories error:', e);
      rethrow;
    }
  }
}

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return OfferRepository(dio);
});