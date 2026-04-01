// lib/features/ussd/services/ussd_service.dart
import 'package:bingwa_pro/core/security/secure_storage_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/logger.dart';

class UssdService {
  final Dio _dio;
  
  UssdService(this._dio);
  
  // This now calls your backend API instead of direct Android USSD
  Future<bool> executeUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Sending USSD request to backend: $ussdCode for $phoneNumber');
      
      final response = await _dio.post('/ussd/execute', data: {
        'action': 'INITIATE',
        'routeCode': ussdCode,
        'agentPhone': phoneNumber,
        'customerPhone': phoneNumber,
        'processingMode': 'EXPRESS',
        'agentId': await _getAgentId(),
      });
      
      final data = response.data;
      AppLogger.d('USSD response: $data');
      
      return data['success'] ?? false;
      
    } on DioException catch (e) {
      AppLogger.e('USSD execution failed:', e);
      return false;
    } catch (e) {
      AppLogger.e('USSD execution error:', e);
      return false;
    }
  }
  
  // Advanced mode - multi-step USSD (now handled by backend)
  Future<bool> executeAdvancedUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Sending Advanced USSD request to backend: $ussdCode for $phoneNumber');
      
      final response = await _dio.post('/ussd/execute', data: {
        'action': 'INITIATE',
        'routeCode': ussdCode,
        'agentPhone': phoneNumber,
        'customerPhone': phoneNumber,
        'processingMode': 'ADVANCED',
        'agentId': await _getAgentId(),
      });
      
      return response.data['success'] ?? false;
      
    } on DioException catch (e) {
      AppLogger.e('Advanced USSD execution failed:', e);
      return false;
    } catch (e) {
      AppLogger.e('Advanced USSD execution error:', e);
      return false;
    }
  }
  
  // Cancel ongoing USSD session
  Future<void> cancelUssd() async {
    try {
      await _dio.post('/ussd/cancel');
      AppLogger.d('USSD session cancelled');
    } catch (e) {
      AppLogger.e('Failed to cancel USSD:', e);
    }
  }
  
  // Helper to get agent ID from secure storage
  Future<String> _getAgentId() async {
    // Import secure storage manager
    final storage = await SecureStorageManager.getAgentId();
    return storage ?? '';
  }
}

final ussdServiceProvider = Provider<UssdService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return UssdService(dio);
});