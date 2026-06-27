// lib/shared/repositories/app_update_repository.dart
// W5.H — reads the advertised latest version (public endpoint; the APK is on your host).
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/app_update_model.dart';

class AppUpdateRepository {
  final Dio _dio;
  AppUpdateRepository(this._dio);

  Future<AppUpdateInfo> getLatest() async {
    final res = await _dio.get('/app-update/latest');
    return AppUpdateInfo.fromJson((res.data as Map).cast<String, dynamic>());
  }
}

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository(ref.watch(dioClientProvider));
});
