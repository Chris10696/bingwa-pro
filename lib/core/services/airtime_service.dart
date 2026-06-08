// lib/core/services/airtime_service.dart
// Thin wrapper over the existing native airtime channel (MainActivity
// AIRTIME_CHANNEL = "bingwa_pro/airtime"). The native side dials *144# through
// UssdEngine (AirtimeChecker) and returns a Map: {success, balance, message}.
//
// NOTE: checking airtime triggers a real *144# USSD dial on the device, so it
// needs the same prerequisites as dialing (CALL_PHONE for Express, or the
// Accessibility service for Advanced). Native returns balance 0.0 if the
// response can't be parsed (it keeps the last known value internally).
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AirtimeService {
  static const MethodChannel _channel = MethodChannel('bingwa_pro/airtime');

  /// Dials *144# natively and returns the parsed airtime balance in KES.
  /// Returns 0.0 if the native side couldn't read/parse a balance.
  Future<double> checkAirtimeBalance() async {
    final dynamic result = await _channel.invokeMethod<dynamic>('checkAirtimeBalance');
    if (result is Map) {
      final dynamic bal = result['balance'];
      if (bal is num) return bal.toDouble();
    }
    return 0.0;
  }
}

final airtimeServiceProvider =
    Provider<AirtimeService>((ref) => AirtimeService());