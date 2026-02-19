import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_model.dart'; // Added import for AgentProfile
import '../models/agent_model.dart';

class AgentRepository {
  final Dio _dio;
  
  AgentRepository(this._dio);
  
  // Get Agent Profile - NEW METHOD ADDED
  Future<AgentProfile> getAgentProfile() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.agentProfile,
      );
      
      final response = await _dio.get(ApiConstants.agentProfile);
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.agentProfile,
        data: response.data,
      );
      
      return AgentProfile.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get agent profile failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent profile error:', e);
      rethrow;
    }
  }
  
  // Get Agent Stats
  Future<AgentStats> getAgentStats({String? period}) async {
    try {
      final params = <String, dynamic>{};
      if (period != null) params['period'] = period;
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.agentStats,
        data: params,
      );
      
      final response = await _dio.get(
        ApiConstants.agentStats,
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.agentStats,
        data: response.data,
      );
      
      return AgentStats.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get agent stats failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent stats error:', e);
      rethrow;
    }
  }
  
  // Get Agent Activity
  Future<List<AgentActivity>> getAgentActivity({
    int? limit,
    int? offset,
    String? activityType,
  }) async {
    try {
      final Map<String, dynamic> params = <String, dynamic>{};
      if (limit != null) params['limit'] = limit;
      if (offset != null) params['offset'] = offset;
      if (activityType != null) params['activity_type'] = activityType;
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/agents/activity',
        data: params,
      );
      
      final response = await _dio.get(
        '/agents/activity',
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/activity',
        data: response.data,
      );
      
      final activities = (response.data['activities'] as List)
          .map((json) => AgentActivity.fromJson(json))
          .toList();
      
      return activities;
    } on DioException catch (e) {
      AppLogger.e('Get agent activity failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent activity error:', e);
      rethrow;
    }
  }
  
  // Get Agent Settings
  Future<AgentSettings> getAgentSettings() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/agents/settings',
      );
      
      final response = await _dio.get('/agents/settings');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/settings',
        data: response.data,
      );
      
      return AgentSettings.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get agent settings failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent settings error:', e);
      rethrow;
    }
  }
  
  // Update Agent Settings
  Future<AgentSettings> updateAgentSettings(AgentSettings settings) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'PUT',
        url: '/agents/settings',
        data: settings.toJson(),
      );
      
      final response = await _dio.put(
        '/agents/settings',
        data: settings.toJson(),
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/settings',
        data: response.data,
      );
      
      final updatedSettings = AgentSettings.fromJson(response.data);
      
      AppLogger.logSessionEvent(
        event: 'Agent settings updated',
        agentId: settings.agentId,
      );
      
      return updatedSettings;
    } on DioException catch (e) {
      AppLogger.e('Update agent settings failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Update agent settings error:', e);
      rethrow;
    }
  }
  
  // Get Agent Documents
  Future<List<AgentDocument>> getAgentDocuments() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/agents/documents',
      );
      
      final response = await _dio.get('/agents/documents');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/documents',
        data: response.data,
      );
      
      final documents = (response.data['documents'] as List)
          .map((json) => AgentDocument.fromJson(json))
          .toList();
      
      return documents;
    } on DioException catch (e) {
      AppLogger.e('Get agent documents failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent documents error:', e);
      rethrow;
    }
  }
  
  // Upload Agent Document
  Future<AgentDocument> uploadAgentDocument({
    required String documentType,
    required String filePath,
    required String fileName,
    String? notes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'document_type': documentType,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        if (notes != null) 'notes': notes,
      });
      
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/agents/documents/upload',
      );
      
      final response = await _dio.post(
        '/agents/documents/upload',
        data: formData,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/documents/upload',
        data: response.data,
      );
      
      final document = AgentDocument.fromJson(response.data);
      
      AppLogger.logSessionEvent(
        event: 'Document uploaded',
        agentId: document.agentId,
        details: 'Type: $documentType',
      );
      
      return document;
    } on DioException catch (e) {
      AppLogger.e('Upload document failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Upload document error:', e);
      rethrow;
    }
  }
  
  // Get Agent Tier
  Future<AgentTier> getAgentTier() async {
    try {
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: '/agents/tier',
      );
      
      final response = await _dio.get('/agents/tier');
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/tier',
        data: response.data,
      );
      
      return AgentTier.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e('Get agent tier failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get agent tier error:', e);
      rethrow;
    }
  }
  
  // Get Commission Summary
  Future<Map<String, dynamic>> getCommissionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.commissionSummary,
        data: params,
      );
      
      final response = await _dio.get(
        ApiConstants.commissionSummary,
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.commissionSummary,
        data: response.data,
      );
      
      return response.data;
    } on DioException catch (e) {
      AppLogger.e('Get commission summary failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get commission summary error:', e);
      rethrow;
    }
  }
  
  // Get Commission History
  Future<List<Map<String, dynamic>>> getCommissionHistory({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (limit != null) params['limit'] = limit;
      if (offset != null) params['offset'] = offset;
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      
      AppLogger.logNetworkRequest(
        method: 'GET',
        url: ApiConstants.commissionHistory,
        data: params,
      );
      
      final response = await _dio.get(
        ApiConstants.commissionHistory,
        queryParameters: params,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: ApiConstants.commissionHistory,
        data: response.data,
      );
      
      return List<Map<String, dynamic>>.from(response.data['commissions']);
    } on DioException catch (e) {
      AppLogger.e('Get commission history failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Get commission history error:', e);
      rethrow;
    }
  }
  
  // Update Agent Profile Picture
  Future<String> updateProfilePicture(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(filePath),
      });
      
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/agents/profile/picture',
      );
      
      final response = await _dio.post(
        '/agents/profile/picture',
        data: formData,
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/profile/picture',
        data: response.data,
      );
      
      final imageUrl = response.data['image_url'];
      
      AppLogger.logSessionEvent(
        event: 'Profile picture updated',
      );
      
      return imageUrl;
    } on DioException catch (e) {
      AppLogger.e('Update profile picture failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Update profile picture error:', e);
      rethrow;
    }
  }
  
  // Change PIN
  Future<void> changePin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/agents/change-pin',
        data: {
          'current_pin': currentPin,
          'new_pin': newPin,
          'confirm_pin': confirmPin,
        },
      );
      
      final response = await _dio.post(
        '/agents/change-pin',
        data: {
          'current_pin': currentPin,
          'new_pin': newPin,
          'confirm_pin': confirmPin,
        },
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/change-pin',
        data: response.data,
      );
      
      AppLogger.logSecurityEvent(
        event: 'PIN changed successfully',
      );
    } on DioException catch (e) {
      AppLogger.e('Change PIN failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Change PIN error:', e);
      rethrow;
    }
  }
  
  // Request Account Deactivation
  Future<void> requestAccountDeactivation(String reason) async {
    try {
      AppLogger.logNetworkRequest(
        method: 'POST',
        url: '/agents/deactivate/request',
        data: {'reason': reason},
      );
      
      final response = await _dio.post(
        '/agents/deactivate/request',
        data: {'reason': reason},
      );
      
      AppLogger.logNetworkResponse(
        statusCode: response.statusCode!,
        url: '/agents/deactivate/request',
        data: response.data,
      );
      
      AppLogger.logSessionEvent(
        event: 'Account deactivation requested',
        details: 'Reason: $reason',
      );
    } on DioException catch (e) {
      AppLogger.e('Account deactivation request failed:', e);
      rethrow;
    } catch (e) {
      AppLogger.e('Account deactivation request error:', e);
      rethrow;
    }
  }
}

// Provider
final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return AgentRepository(dio);
});