import 'package:flutter/material.dart';
import '../errors/failures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

class ErrorDisplayWidget extends ConsumerWidget {
  final Failure failure;
  final VoidCallback? onRetry;
  final String? customMessage;
  
  const ErrorDisplayWidget({
    super.key,
    required this.failure,
    this.onRetry,
    this.customMessage,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = customMessage ?? _getErrorMessage(failure);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(failure),
              size: 64,
              color: _getErrorColor(failure),
            ),
            const SizedBox(height: 20),
            Text(
              _getErrorTitle(failure),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _getErrorColor(failure),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getErrorColor(failure),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                AppLogger.e('Error details:', failure.exception);
                _showErrorDetails(context, failure);
              },
              child: const Text('Show Details'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getErrorMessage(Failure failure) {
    switch (failure.code) {
      case 'NETWORK_ERROR':
        return 'Please check your internet connection and try again.';
      case 'UNAUTHORIZED':
        return 'Your session has expired. Please login again.';
      case 'INSUFFICIENT_TOKENS':
        return 'Please top up your wallet to continue.';
      case 'USSD_TIMEOUT':
        return 'The transaction timed out. Please try again.';
      case 'USSD_ANOMALY':
        return 'System detected unusual response. Contact support.';
      case 'VALIDATION_ERROR':
        return 'Please check your input and try again.';
      default:
        return failure.message;
    }
  }
  
  String _getErrorTitle(Failure failure) {
    switch (failure.code) {
      case 'NETWORK_ERROR':
        return 'No Connection';
      case 'UNAUTHORIZED':
        return 'Session Expired';
      case 'INSUFFICIENT_TOKENS':
        return 'Insufficient Tokens';
      case 'USSD_TIMEOUT':
        return 'Transaction Timeout';
      case 'USSD_ANOMALY':
        return 'Security Alert';
      default:
        return 'Error Occurred';
    }
  }
  
  IconData _getErrorIcon(Failure failure) {
    switch (failure.code) {
      case 'NETWORK_ERROR':
        return Icons.wifi_off;
      case 'UNAUTHORIZED':
        return Icons.lock_outline;
      case 'INSUFFICIENT_TOKENS':
        return Icons.account_balance_wallet;
      case 'USSD_TIMEOUT':
        return Icons.timer_off;
      case 'USSD_ANOMALY':
        return Icons.security;
      default:
        return Icons.error_outline;
    }
  }
  
  Color _getErrorColor(Failure failure) {
    switch (failure.code) {
      case 'NETWORK_ERROR':
        return Colors.orange;
      case 'UNAUTHORIZED':
        return Colors.red;
      case 'INSUFFICIENT_TOKENS':
        return Colors.amber;
      case 'USSD_TIMEOUT':
        return Colors.blue;
      case 'USSD_ANOMALY':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
  
  void _showErrorDetails(BuildContext context, Failure failure) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Message: ${failure.message}'),
              const SizedBox(height: 8),
              Text('Code: ${failure.code ?? "N/A"}'),
              if (failure.exception != null) ...[
                const SizedBox(height: 8),
                Text('Exception: ${failure.exception.toString()}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Copy error details to clipboard
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}