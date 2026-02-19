import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../security/secure_storage_manager.dart';

class AuthInterceptor extends Interceptor {
  final Ref ref;
  
  AuthInterceptor(this.ref);
  
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get auth token from secure storage
    final token = await SecureStorageManager.getAuthToken();
    
    // Add authorization header if token exists
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add device fingerprint if available
    final deviceId = await SecureStorageManager.getDeviceId();
    if (deviceId != null) {
      options.headers['X-Device-Id'] = deviceId;
    }
    
    // Add request ID for tracking
    options.headers['X-Request-ID'] = DateTime.now().microsecondsSinceEpoch.toString();
    
    handler.next(options);
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized errors
    if (err.response?.statusCode == 401) {
      // Clear tokens and redirect to login
      await SecureStorageManager.clearAll();
      
      // TODO: Trigger logout flow via Riverpod
      // ref.read(authNotifierProvider.notifier).logout();
    }
    
    handler.next(err);
  }
}