import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/logger.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final Dio _dio;
  
  CustomerRepository(this._dio);
  
  // Get all customers for current agent
  Future<CustomerListResponse> getCustomers(CustomerFilter filter) async {
    try {
      final params = <String, dynamic>{
        'page': filter.page,
        'pageSize': filter.pageSize,
        'sortBy': filter.sortBy,
        'sortDesc': filter.sortDesc,
      };
      
      if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
        params['search'] = filter.searchTerm;
      }
      if (filter.isBlacklisted != null) {
        params['blacklisted'] = filter.isBlacklisted;
      }
      if (filter.createdAfter != null) {
        params['createdAfter'] = filter.createdAfter!.toIso8601String();
      }
      if (filter.createdBefore != null) {
        params['createdBefore'] = filter.createdBefore!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/customers',
        data: params,
      );
      
      final response = await _dio.get(
        '/customers',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers',
        data: response.data,
      );
      
      return CustomerListResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get customers failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get customers error:', e);
      rethrow;
    }
  }
  
  // Get single customer by ID
  Future<Customer> getCustomer(String customerId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/customers/$customerId',
      );
      
      final response = await _dio.get('/customers/$customerId');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/$customerId',
        data: response.data,
      );
      
      return Customer.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get customer error:', e);
      rethrow;
    }
  }
  
  // Get customer transaction summary
  Future<CustomerTransactionSummary> getCustomerSummary(String customerId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/customers/$customerId/summary',
      );
      
      final response = await _dio.get('/customers/$customerId/summary');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/$customerId/summary',
        data: response.data,
      );
      
      return CustomerTransactionSummary.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get customer summary failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get customer summary error:', e);
      rethrow;
    }
  }
  
  // Create new customer
  Future<Customer> createCustomer(CreateCustomerRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/customers',
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        '/customers',
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers',
        data: response.data,
      );
      
      final customer = Customer.fromJson(response.data);
      
      AppLogger.logSessionEvent(
        event: 'Customer created',
        details: 'Customer: ${customer.fullName}, Phone: ${customer.phoneNumber}',
      );
      
      return customer;
    } on DioException catch (e) {
      AppLogger.e('Create customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Create customer error:', e);
      rethrow;
    }
  }
  
  // Update customer
  Future<Customer> updateCustomer(String customerId, UpdateCustomerRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'PUT',
        url: '/customers/$customerId',
        data: request.toJson(),
      );
      
      final response = await _dio.put(
        '/customers/$customerId',
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/$customerId',
        data: response.data,
      );
      
      return Customer.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Update customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Update customer error:', e);
      rethrow;
    }
  }
  
  // Blacklist customer
  Future<Customer> blacklistCustomer(BlacklistRequest request) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/customers/${request.customerId}/blacklist',
        data: request.toJson(),
      );
      
      final response = await _dio.post(
        '/customers/${request.customerId}/blacklist',
        data: request.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/${request.customerId}/blacklist',
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'Customer blacklisted',
        details: 'Customer ID: ${request.customerId}, Reason: ${request.reason}',
      );
      
      return Customer.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Blacklist customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Blacklist customer error:', e);
      rethrow;
    }
  }
  
  // Remove from blacklist
  Future<Customer> unblacklistCustomer(String customerId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'DELETE',
        url: '/customers/$customerId/blacklist',
      );
      
      final response = await _dio.delete('/customers/$customerId/blacklist');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/$customerId/blacklist',
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'Customer removed from blacklist',
        details: 'Customer ID: $customerId',
      );
      
      return Customer.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Unblacklist customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Unblacklist customer error:', e);
      rethrow;
    }
  }
  
  // Delete customer
  Future<void> deleteCustomer(String customerId) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'DELETE',
        url: '/customers/$customerId',
      );
      
      final response = await _dio.delete('/customers/$customerId');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/$customerId',
        data: response.data,
      );
      
      AppLogger.logSessionEvent(
        event: 'Customer deleted',
        details: 'Customer ID: $customerId',
      );
    } on DioException catch (e) {
      AppLogger.e('Delete customer failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Delete customer error:', e);
      rethrow;
    }
  }
  
  // Search customers
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/customers/search',
        data: {'q': query},
      );
      
      final response = await _dio.get(
        '/customers/search',
        queryParameters: {'q': query},
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/customers/search',
        data: response.data,
      );
      
      final customers = (response.data['customers'] as List)
          .map((json) => Customer.fromJson(json))
          .toList();
      
      return customers;
    } on DioException catch (e) {
      AppLogger.e('Search customers failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Search customers error:', e);
      rethrow;
    }
  }
}

// Provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CustomerRepository(dio);
});