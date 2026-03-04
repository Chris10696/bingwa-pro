import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/logger.dart';
import '../models/report_model.dart';

class ReportsRepository {
  final Dio _dio;
  
  ReportsRepository(this._dio);
  
  // Get transaction summary
  Future<TransactionSummary> getTransactionSummary(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      if (filter.agentId != null) {
        params['agentId'] = filter.agentId;
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/summary',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/summary',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/summary',
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
  
  // Get top products
  Future<List<ProductPerformance>> getTopProducts(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
        'limit': filter.limit,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      if (filter.productType != null) {
        params['productType'] = filter.productType;
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/top-products',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/top-products',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/top-products',
        data: response.data,
      );
      
      final products = (response.data['products'] as List)
          .map((json) => ProductPerformance.fromJson(json))
          .toList();
      
      return products;
    } on DioException catch (e) {
      AppLogger.e('Get top products failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get top products error:', e);
      rethrow;
    }
  }
  
  // Get daily stats
  Future<List<DailyTransactionStats>> getDailyStats(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/daily-stats',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/daily-stats',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/daily-stats',
        data: response.data,
      );
      
      final stats = (response.data['stats'] as List)
          .map((json) => DailyTransactionStats.fromJson(json))
          .toList();
      
      return stats;
    } on DioException catch (e) {
      AppLogger.e('Get daily stats failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get daily stats error:', e);
      rethrow;
    }
  }
  
  // Get hourly distribution
  Future<List<HourlyDistribution>> getHourlyDistribution(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/hourly-distribution',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/hourly-distribution',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/hourly-distribution',
        data: response.data,
      );
      
      final distribution = (response.data['distribution'] as List)
          .map((json) => HourlyDistribution.fromJson(json))
          .toList();
      
      return distribution;
    } on DioException catch (e) {
      AppLogger.e('Get hourly distribution failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get hourly distribution error:', e);
      rethrow;
    }
  }
  
  // Get top customers
  Future<List<TopCustomer>> getTopCustomers(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
        'limit': filter.limit,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/top-customers',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/top-customers',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/top-customers',
        data: response.data,
      );
      
      final customers = (response.data['customers'] as List)
          .map((json) => TopCustomer.fromJson(json))
          .toList();
      
      return customers;
    } on DioException catch (e) {
      AppLogger.e('Get top customers failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get top customers error:', e);
      rethrow;
    }
  }
  
  // Get complete report data
  Future<ReportData> getReportData(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
        'limit': filter.limit,
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      if (filter.agentId != null) {
        params['agentId'] = filter.agentId;
      }
      if (filter.productType != null) {
        params['productType'] = filter.productType;
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/data',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/data',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/data',
        data: response.data,
      );
      
      return ReportData.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get report data failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get report data error:', e);
      rethrow;
    }
  }
  
  // Export report as CSV
  Future<String> exportReportCsv(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
        'format': 'csv',
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/export',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.plain),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/export',
        data: 'CSV data received',
      );
      
      return response.data as String;
    } on DioException catch (e) {
      AppLogger.e('Export report CSV failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Export report CSV error:', e);
      rethrow;
    }
  }
  
  // Export report as PDF
  Future<String> exportReportPdf(ReportFilter filter) async {
    try {
      final params = <String, dynamic>{
        'period': filter.period.name,
        'format': 'pdf',
      };
      
      if (filter.startDate != null) {
        params['startDate'] = filter.startDate!.toIso8601String();
      }
      if (filter.endDate != null) {
        params['endDate'] = filter.endDate!.toIso8601String();
      }
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/reports/export',
        data: params,
      );
      
      final response = await _dio.get(
        '/reports/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.plain),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/reports/export',
        data: 'PDF data received',
      );
      
      return response.data as String;
    } on DioException catch (e) {
      AppLogger.e('Export report PDF failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Export report PDF error:', e);
      rethrow;
    }
  }
}

// Provider
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ReportsRepository(dio);
});