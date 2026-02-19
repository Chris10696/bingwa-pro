import 'exceptions.dart';

abstract class Failure {
  final String message;
  final String? code;
  final Exception? exception;
  
  const Failure(this.message, {this.code, this.exception});
  
  @override
  String toString() => 'Failure: $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {Exception? exception})
      : super(message, code: 'NETWORK_ERROR', exception: exception);
}

class ApiFailure extends Failure {
  final int? statusCode;
  
  const ApiFailure(String message, {this.statusCode, Exception? exception})
      : super(message, code: 'API_ERROR', exception: exception);
}

class AuthFailure extends Failure {
  const AuthFailure(String message, {Exception? exception})
      : super(message, code: 'AUTH_ERROR', exception: exception);
}

class ValidationFailure extends Failure {
  final Map<String, dynamic> errors;
  
  const ValidationFailure(String message, this.errors, {Exception? exception})
      : super(message, code: 'VALIDATION_ERROR', exception: exception);
}

class TransactionFailure extends Failure {
  const TransactionFailure(String message, {Exception? exception})
      : super(message, code: 'TRANSACTION_ERROR', exception: exception);
}

class PaymentFailure extends Failure {
  const PaymentFailure(String message, {Exception? exception})
      : super(message, code: 'PAYMENT_ERROR', exception: exception);
}

class StorageFailure extends Failure {
  const StorageFailure(String message, {Exception? exception})
      : super(message, code: 'STORAGE_ERROR', exception: exception);
}

class UssdFailure extends Failure {
  const UssdFailure(String message, {Exception? exception})
      : super(message, code: 'USSD_ERROR', exception: exception);
}

class DeviceFailure extends Failure {
  const DeviceFailure(String message, {Exception? exception})
      : super(message, code: 'DEVICE_ERROR', exception: exception);
}

class GenericFailure extends Failure {
  const GenericFailure(String message, {String? code, Exception? exception})
      : super(message, code: code, exception: exception);
}

// Helper method to convert exceptions to failures
Failure exceptionToFailure(Exception exception) {
  if (exception is NetworkException) {
    return NetworkFailure(exception.message, exception: exception);
  } else if (exception is SocketException) {
    return NetworkFailure('No internet connection', exception: exception);
  } else if (exception is TimeoutException) {
    return NetworkFailure('Request timeout', exception: exception);
  } else if (exception is ApiException) {
    return ApiFailure(
      exception.message,
      statusCode: exception.statusCode,
      exception: exception,
    );
  } else if (exception is UnauthorizedException) {
    return AuthFailure('Session expired. Please login again.', exception: exception);
  } else if (exception is InvalidCredentialsException) {
    return AuthFailure('Invalid credentials', exception: exception);
  } else if (exception is SuspendedAccountException) {
    return AuthFailure('Account suspended', exception: exception);
  } else if (exception is InsufficientTokensException) {
    return TransactionFailure(exception.message, exception: exception);
  } else if (exception is TransactionFailedException) {
    return TransactionFailure(exception.message, exception: exception);
  } else if (exception is UssdException) {
    return UssdFailure(exception.message, exception: exception);
  } else if (exception is PaymentException) {
    return PaymentFailure(exception.message, exception: exception);
  } else if (exception is ValidationException) {
    return ValidationFailure(exception.message, exception.errors, exception: exception);
  } else if (exception is StorageException) {
    return StorageFailure(exception.message, exception: exception);
  } else if (exception is RootedDeviceException) {
    return DeviceFailure(exception.message, exception: exception);
  } else if (exception is AppException) {
    return GenericFailure(exception.message, code: exception.code, exception: exception);
  } else {
    return GenericFailure('An unexpected error occurred', exception: exception);
  }
}