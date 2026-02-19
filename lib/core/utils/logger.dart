import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _instance = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false, // Changed to false to fix deprecation
    ),
  );
  
  static void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.t(message, error: error, stackTrace: stackTrace);
  }
  
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.d(message, error: error, stackTrace: stackTrace);
  }
  
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.i(message, error: error, stackTrace: stackTrace);
  }
  
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.w(message, error: error, stackTrace: stackTrace);
  }
  
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.e(message, error: error, stackTrace: stackTrace);
  }
  
  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.f(message, error: error, stackTrace: stackTrace);
  }
  
  static void logNetworkRequest({
    required String method,
    required String url,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    _instance.i('🌐 $method $url');
    
    if (data != null) {
      _instance.d('Request Data: $data');
    }
    
    if (headers != null && headers.isNotEmpty) {
      _instance.d('Headers: $headers');
    }
  }
  
  static void logNetworkResponse({
    required int statusCode,
    required String url,
    dynamic data,
  }) {
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    _instance.i('$emoji $statusCode $url');
    
    if (data != null) {
      _instance.d('Response Data: $data');
    }
  }
  
  static void logTransaction({
    required String type,
    required String phone,
    required double amount,
    required String status,
    String? reference,
  }) {
    // Format amount as currency (KES)
    final formattedAmount = _formatCurrency(amount);
    
    _instance.i('💰 $type Transaction: $phone - $formattedAmount');
    _instance.d('Status: $status | Reference: ${reference ?? "N/A"}');
  }
  
  static void logSecurityEvent({
    required String event,
    String? agentId,
    String? details,
  }) {
    _instance.w('🔒 Security Event: $event');
    _instance.d('Agent: ${agentId ?? "Unknown"} | Details: $details');
  }
  
  static void logSessionEvent({
    required String event,
    String? agentId,
    String? details,
  }) {
    _instance.i('🔑 Session Event: $event');
    _instance.d('Agent: ${agentId ?? "Unknown"} | Details: $details');
  }
  
  // Helper method to format currency
  static String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }
}