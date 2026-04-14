// lib/features/ussd/services/ussd_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/secure_storage_manager.dart';
import '../../../core/utils/logger.dart';

class UssdService {
  static const MethodChannel _ussdChannel = MethodChannel('bingwa_pro/ussd');
  static const MethodChannel _airtimeChannel = MethodChannel('bingwa_pro/airtime');
  static const MethodChannel _serviceChannel = MethodChannel('bingwa_pro/service');
  
  // ===== USSD EXECUTION =====
  
  // Express mode - single-step USSD
  Future<bool> executeUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Executing EXPRESS USSD: $ussdCode for $phoneNumber');
      
      final result = await _ussdChannel.invokeMethod('executeUssd', {
        'ussdCode': ussdCode,
        'phoneNumber': phoneNumber,
      });
      
      AppLogger.d('EXPRESS USSD result: $result');
      return result['success'] ?? false;
      
    } on PlatformException catch (e) {
      AppLogger.e('EXPRESS USSD execution failed:', e);
      return false;
    }
  }
  
  // Advanced mode - multi-step USSD
  Future<bool> executeAdvancedUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Executing ADVANCED USSD: $ussdCode for $phoneNumber');
      
      final result = await _ussdChannel.invokeMethod('executeAdvancedUssd', {
        'ussdCode': ussdCode,
        'phoneNumber': phoneNumber,
      });
      
      AppLogger.d('ADVANCED USSD result: $result');
      return result['success'] ?? false;
      
    } on PlatformException catch (e) {
      AppLogger.e('ADVANCED USSD execution failed:', e);
      return false;
    }
  }
  
  // Cancel ongoing USSD session
  Future<void> cancelUssd() async {
    try {
      await _ussdChannel.invokeMethod('cancelUssd');
      AppLogger.d('USSD cancelled');
    } on PlatformException catch (e) {
      AppLogger.e('Failed to cancel USSD:', e);
    }
  }
  
  // ===== AIRTIME BALANCE =====
  
  // Check current airtime balance
  Future<double> checkAirtimeBalance() async {
    try {
      AppLogger.d('Checking airtime balance...');
      
      final result = await _airtimeChannel.invokeMethod('checkAirtimeBalance');
      
      AppLogger.d('Airtime balance result: $result');
      return (result['balance'] as num?)?.toDouble() ?? 0.0;
      
    } on PlatformException catch (e) {
      AppLogger.e('Failed to check airtime balance:', e);
      return 0.0;
    }
  }
  
  // ===== SERVICE CONTROL =====
  
  // Start the background USSD service
  Future<bool> startUssdService() async {
    try {
      AppLogger.d('Starting USSD background service...');
      
      final result = await _serviceChannel.invokeMethod('startService');
      AppLogger.d('Service start result: $result');
      return result ?? false;
      
    } on PlatformException catch (e) {
      AppLogger.e('Failed to start USSD service:', e);
      return false;
    }
  }
  
  // Stop the background USSD service
  Future<bool> stopUssdService() async {
    try {
      AppLogger.d('Stopping USSD background service...');
      
      final result = await _serviceChannel.invokeMethod('stopService');
      AppLogger.d('Service stop result: $result');
      return result ?? false;
      
    } on PlatformException catch (e) {
      AppLogger.e('Failed to stop USSD service:', e);
      return false;
    }
  }
  
  // Check if service is running
  Future<bool> isUssdServiceRunning() async {
    try {
      final result = await _serviceChannel.invokeMethod('isServiceRunning');
      return result ?? false;
      
    } on PlatformException catch (e) {
      AppLogger.e('Failed to check service status:', e);
      return false;
    }
  }
}

final ussdServiceProvider = Provider<UssdService>((ref) {
  return UssdService();
});