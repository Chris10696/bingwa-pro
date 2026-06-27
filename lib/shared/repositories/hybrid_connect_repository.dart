// lib/shared/repositories/hybrid_connect_repository.dart
// W5.F.3 — Connect-ID issuance for HybridConnect/Portal (backend src/hybrid-connect,
// JWT-scoped via the AuthInterceptor). The agent generates a Connect ID, shares it with
// the web Portal, and both join the socket room for that ID.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class HybridConnectRepository {
  final Dio _dio;
  HybridConnectRepository(this._dio);

  /// The agent's current Connect ID, or null if none has been generated yet.
  Future<String?> getConnectId() async {
    final res = await _dio.get('/hybrid-connect');
    final data = (res.data as Map).cast<String, dynamic>();
    final id = data['connectId'];
    return (id is String && id.isNotEmpty) ? id : null;
  }

  /// Generate (or reuse — the backend store is stable per agent) the Connect ID.
  Future<String> generateConnectId() async {
    final res = await _dio.post('/hybrid-connect/generate');
    final data = (res.data as Map).cast<String, dynamic>();
    final id = data['connectId'];
    if (id is! String || id.isEmpty) {
      // Mirror Hybrid's guard wording.
      throw Exception(
          'Generated connect ID is too short or empty. Please try again');
    }
    return id;
  }
}

final hybridConnectRepositoryProvider = Provider<HybridConnectRepository>((ref) {
  return HybridConnectRepository(ref.watch(dioClientProvider));
});
