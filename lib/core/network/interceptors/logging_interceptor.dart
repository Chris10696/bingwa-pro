import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class LoggingInterceptor extends Interceptor {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.i(
      '🌐 REQUEST: ${options.method} ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Data: ${options.data}',
    );
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.i(
      '✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}\n'
      'Data: ${response.data}',
    );
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '❌ ERROR: ${err.type} ${err.response?.statusCode}\n'
      'Message: ${err.message}\n'
      'Response: ${err.response?.data}',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}