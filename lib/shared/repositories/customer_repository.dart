// lib/shared/repositories/customer_repository.dart
// W4-batch-3b — reshaped to the Hybrid-minimal customer model + the real backend
// endpoints (src/customers). Blacklist is a flag toggled by POST/DELETE /:id/blacklist.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/logger.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final Dio _dio;
  CustomerRepository(this._dio);

  Future<CustomerListResponse> getCustomers(CustomerFilter filter) async {
    try {
      final params = <String, dynamic>{};
      if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
        params['search'] = filter.searchTerm;
      }
      if (filter.isBlacklisted != null) {
        params['blacklisted'] = filter.isBlacklisted;
      }
      final response = await _dio.get('/customers', queryParameters: params);
      return CustomerListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.e('Get customers failed:', e);
      rethrow;
    }
  }

  Future<Customer> getCustomer(String id) async {
    final response = await _dio.get('/customers/$id');
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Customer> createCustomer(CreateCustomerRequest request) async {
    final response = await _dio.post('/customers', data: request.toJson());
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Customer> updateCustomer(
    String id,
    UpdateCustomerRequest request,
  ) async {
    final response = await _dio.put('/customers/$id', data: request.toJson());
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Customer> blacklistCustomer(String id) async {
    final response = await _dio.post('/customers/$id/blacklist');
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Customer> unblacklistCustomer(String id) async {
    final response = await _dio.delete('/customers/$id/blacklist');
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(String id) async {
    await _dio.delete('/customers/$id');
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final response = await _dio.get(
      '/customers/search',
      queryParameters: {'q': query},
    );
    final list = (response.data['customers'] as List<dynamic>?) ?? const [];
    return list
        .map((j) => Customer.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CustomerRepository(dio);
});
