// lib/core/services/schedule_service.dart
//
// W3.E — Dart side of device-side scheduled firing.
//
// Thin wrapper over the `bingwa_pro/scheduler` MethodChannel. When an
// auto-renewal is scheduled, Dart calls [arm] so the native WorkScheduler
// enqueues a WorkManager one-shot keyed by transactionId; cancelling the
// schedule calls [cancel]. The worker itself (ScheduleTransactionWorker, Kotlin)
// fetches the row and fires the dial at the due time.
//
// Failures here are intentionally swallowed (logged, not rethrown): the
// scheduled row is already persisted server-side, so a transient channel/arming
// hiccup must not surface as a "schedule failed" error to the agent. A future
// app-launch reconcile re-arms anything that slipped through.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScheduleService {
  static const MethodChannel _channel = MethodChannel('bingwa_pro/scheduler');

  /// Arm a device-side one-shot to fire [transactionId] at [scheduledFor].
  /// A past time fires as soon as the device has network (handles overdue rows).
  Future<void> arm({
    required String transactionId,
    required DateTime scheduledFor,
  }) async {
    try {
      await _channel.invokeMethod<bool>('armScheduled', <String, dynamic>{
        'transactionId': transactionId,
        // Epoch millis is timezone-independent; native reads it as a Long.
        'triggerAtMillis': scheduledFor.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('ScheduleService.arm failed ($transactionId): ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('ScheduleService.arm channel unavailable: ${e.message}');
    }
  }

  /// Tear down the armed one-shot for a cancelled scheduled transaction.
  Future<void> cancel(String transactionId) async {
    try {
      await _channel.invokeMethod<bool>('cancelScheduled', <String, dynamic>{
        'transactionId': transactionId,
      });
    } on PlatformException catch (e) {
      debugPrint('ScheduleService.cancel failed ($transactionId): ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('ScheduleService.cancel channel unavailable: ${e.message}');
    }
  }
}

final scheduleServiceProvider =
    Provider<ScheduleService>((ref) => ScheduleService());