// lib/shared/repositories/account_health_repository.dart
// W5.C — GET /account-health (agent-scoped via JWT). Backend stub returns HEALTHY.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../models/account_health_model.dart';

class AccountHealthRepository {
  final Dio _dio;
  AccountHealthRepository(this._dio);

  Future<AccountHealth> getHealth() async {
    final response = await _dio.get('/account-health');
    return AccountHealth.fromJson((response.data as Map).cast<String, dynamic>());
  }
}

final accountHealthRepositoryProvider = Provider<AccountHealthRepository>((ref) {
  return AccountHealthRepository(ref.watch(dioClientProvider));
});
