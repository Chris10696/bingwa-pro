// lib/features/ussd/services/ussd_service.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/logger.dart';

class UssdService {
  static const MethodChannel _channel = MethodChannel('bingwa_pro/ussd');
  
  // Express mode - single USSD execution
  Future<bool> executeUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Executing USSD: $ussdCode for $phoneNumber');
      
      final result = await _channel.invokeMethod('executeUssd', {
        'ussdCode': ussdCode,
        'phoneNumber': phoneNumber,
      });
      
      return result['success'] ?? false;
    } on PlatformException catch (e) {
      AppLogger.e('USSD execution failed:', e);
      return false;
    }
  }
  
  // Advanced mode - multi-step USSD
  Future<bool> executeAdvancedUssd({
    required String ussdCode,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.d('Executing Advanced USSD: $ussdCode for $phoneNumber');
      
      final result = await _channel.invokeMethod('executeAdvancedUssd', {
        'ussdCode': ussdCode,
        'phoneNumber': phoneNumber,
      });
      
      return result['success'] ?? false;
    } on PlatformException catch (e) {
      AppLogger.e('Advanced USSD execution failed:', e);
      return false;
    }
  }
  
  // Cancel ongoing USSD session
  Future<void> cancelUssd() async {
    try {
      await _channel.invokeMethod('cancelUssd');
    } on PlatformException catch (e) {
      AppLogger.e('Failed to cancel USSD:', e);
    }
  }
}

final ussdServiceProvider = Provider<UssdService>((ref) {
  return UssdService();
});