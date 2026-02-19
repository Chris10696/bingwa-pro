import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static final Logger _logger = Logger();
  
  static void logError(dynamic error, StackTrace? stackTrace, {String? context}) {
    _logger.e(
      'Error${context != null ? ' in $context' : ''}',
      error: error,
      stackTrace: stackTrace,
    );
    
    // TODO: Send to crash reporting service (Sentry, Firebase Crashlytics)
    // _reportError(error, stackTrace, context);
  }
  
  static String getUserFriendlyMessage(Failure failure) {
    switch (failure.code) {
      case 'NETWORK_ERROR':
        return 'No internet connection. Please check your network and try again.';
      case 'UNAUTHORIZED':
        return 'Session expired. Please login again.';
      case 'FORBIDDEN':
        return 'Access denied. Contact administrator.';
      case 'VALIDATION_ERROR':
        return 'Please check your input and try again.';
      case 'INSUFFICIENT_TOKENS':
        return 'Insufficient tokens. Please top up your wallet.';
      case 'USSD_TIMEOUT':
        return 'Transaction timed out. Please try again.';
      case 'USSD_ANOMALY':
        return 'System detected unusual response. Transaction blocked for safety.';
      case 'PAYMENT_FAILED':
        return 'Payment failed. Please try again or use a different method.';
      case 'DUPLICATE_TRANSACTION':
        return 'Duplicate transaction detected. Please check your transaction history.';
      case 'DEVICE_ROOTED':
        return 'App cannot run on modified devices for security reasons.';
      default:
        return failure.message.isNotEmpty 
            ? failure.message 
            : 'An unexpected error occurred. Please try again.';
    }
  }
  
  static Widget buildErrorWidget(Failure failure, VoidCallback? onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              getUserFriendlyMessage(failure),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  static void showErrorSnackbar(BuildContext context, Failure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getUserFriendlyMessage(failure)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    VoidCallback? onConfirm,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (confirmText != null && onConfirm != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }
  
  // Future<void> _reportError(
  //   dynamic error,
  //   StackTrace? stackTrace,
  //   String? context,
  // ) async {
  //   // Implementation for crash reporting service
  //   // await Sentry.captureException(error, stackTrace: stackTrace);
  // }
}