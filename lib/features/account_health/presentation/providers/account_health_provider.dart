// lib/features/account_health/presentation/providers/account_health_provider.dart
// W5.C — fetches the agent's account standing and mirrors it to native (SessionBridge), so the
// USSD dial pipeline can gate. Fail-OPEN: any error → treated as healthy (never block selling on
// a transient health-check failure). The dashboard watches this for its restriction banner.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';
import '../../../../shared/models/account_health_model.dart';
import '../../../../shared/repositories/account_health_repository.dart';

final accountHealthProvider =
    FutureProvider.autoDispose<AccountHealth>((ref) async {
  final bridge = ref.read(sessionBridgeServiceProvider);
  try {
    final health = await ref.read(accountHealthRepositoryProvider).getHealth();
    await bridge.saveAccountHealthy(health.isHealthy);
    return health;
  } catch (_) {
    await bridge.saveAccountHealthy(true); // fail-open
    return const AccountHealth(status: AccountHealthStatus.unknown);
  }
});

// W5.D — whether the device's automatic date & time is ON (false → the engine won't dial,
// so the dashboard warns the agent). Native check via SessionBridge.
final autoTimeProvider = FutureProvider.autoDispose<bool>(
  (ref) async => ref.read(sessionBridgeServiceProvider).isAutoTimeEnabled(),
);
