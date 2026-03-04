import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_router.dart'; // Import for appRouterProvider
import '../../security/secure_storage_manager.dart';
import '../../utils/logger.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

class AuthInterceptor extends Interceptor {
  final Ref ref;
  
  AuthInterceptor(this.ref);
  
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }
    
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
      AppLogger.w('Received 401 error, logging out');
      
      try {
        // Clear all tokens from secure storage
        await SecureStorageManager.clearAll();
        
        // Trigger logout flow via Riverpod
        try {
          final authNotifier = ref.read(authNotifierProvider.notifier);
          await authNotifier.logout();
        } catch (riverpodError) {
          AppLogger.e('Error during Riverpod logout', riverpodError);
        }
        
        // Navigate to login screen using GoRouter
        try {
          final router = ref.read(appRouterProvider);
          router.go('/login');
        } catch (routerError) {
          AppLogger.e('Error during navigation', routerError);
        }
      } catch (e) {
        AppLogger.e('Error during 401 logout', e);
      }
    }
    
    handler.next(err);
  }
  
  bool _isPublicEndpoint(String path) {
    final publicPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/refresh',
      '/auth/verify-phone',
      '/auth/reset-pin',
    ];
    
    return publicPaths.any((publicPath) => path.contains(publicPath));
  }
}