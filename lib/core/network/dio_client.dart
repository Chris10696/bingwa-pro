import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/error_interceptor.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': AppConstants.appVersion,
        'X-Platform': 'android',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  
  // Add interceptors in order
  dio.interceptors.add(LoggingInterceptor());
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(ErrorInterceptor());
  
  // Add retry interceptor for network errors
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error)) {
          await Future.delayed(AppConstants.retryDelay);
          try {
            final response = await dio.request(
              error.requestOptions.path,
              data: error.requestOptions.data,
              options: Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              ),
            );
            handler.resolve(response);
          } catch (retryError) {
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    ),
  );
  
  return dio;
});

bool _shouldRetry(DioException error) {
  return error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError;
}