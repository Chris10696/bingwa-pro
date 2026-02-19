import 'package:dio/dio.dart';
import '/../core/errors/exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DioException modifiedError = err;
    
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      modifiedError = err.copyWith(
        error: TimeoutException('Request timeout'),
      );
    } else if (err.type == DioExceptionType.connectionError) {
      modifiedError = err.copyWith(
        error: NetworkException('No internet connection'),
      );
    } else if (err.response != null) {
      // Handle API errors
      final statusCode = err.response!.statusCode;
      final data = err.response!.data;
      
      switch (statusCode) {
        case 400:
          modifiedError = err.copyWith(
            error: ApiException(
              data['message'] ?? 'Bad request',
              code: data['code'],
              statusCode: statusCode,
            ),
          );
        case 401:
          modifiedError = err.copyWith(
            error: UnauthorizedException(
              data['message'] ?? 'Unauthorized',
            ),
          );
        case 403:
          modifiedError = err.copyWith(
            error: ForbiddenException(
              data['message'] ?? 'Forbidden',
            ),
          );
        case 404:
          modifiedError = err.copyWith(
            error: NotFoundException(
              data['message'] ?? 'Not found',
            ),
          );
        case 422:
          modifiedError = err.copyWith(
            error: ValidationException(
              data['message'] ?? 'Validation error',
              data['errors'] ?? {},
            ),
          );
        case 500:
        case 502:
        case 503:
        case 504:
          modifiedError = err.copyWith(
            error: ApiException(
              'Server error. Please try again later.',
              code: 'SERVER_ERROR',
              statusCode: statusCode,
            ),
          );
        default:
          modifiedError = err.copyWith(
            error: ApiException(
              data['message'] ?? 'Unknown error',
              code: data['code'],
              statusCode: statusCode,
            ),
          );
      }
    }
    
    handler.next(modifiedError);
  }
}