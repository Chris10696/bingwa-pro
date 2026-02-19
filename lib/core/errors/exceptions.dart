// Base Exception
class AppException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;
  
  const AppException(this.message, {this.code, this.stackTrace});
  
  @override
  String toString() => 'AppException: $message ${code != null ? '($code)' : ''}';
}

// Network Exceptions
class NetworkException extends AppException {
  const NetworkException(String message) : super(message);
}

class SocketException extends NetworkException {
  const SocketException(String message) : super(message);
}

class TimeoutException extends NetworkException {
  const TimeoutException(String message) : super(message);
}

// API Exceptions
class ApiException extends AppException {
  final int? statusCode;
  
  const ApiException(String message, {String? code, this.statusCode})
      : super(message, code: code);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(String message) 
      : super(message, code: 'UNAUTHORIZED', statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(String message) 
      : super(message, code: 'FORBIDDEN', statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException(String message) 
      : super(message, code: 'NOT_FOUND', statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic> errors;
  
  const ValidationException(String message, this.errors)
      : super(message, code: 'VALIDATION_ERROR', statusCode: 422);
}

// Auth Exceptions
class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException() 
      : super('Invalid phone number or PIN');
}

class SuspendedAccountException extends AppException {
  const SuspendedAccountException() 
      : super('Account suspended. Contact administrator.');
}

class AccountNotVerifiedException extends AppException {
  const AccountNotVerifiedException() 
      : super('Account not verified. Please complete verification.');
}

class AgentNotFoundException extends AppException {
  const AgentNotFoundException() 
      : super('Agent not found. Please register first.');
}

// Transaction Exceptions
class InsufficientTokensException extends AppException {
  const InsufficientTokensException(double required)
      : super('Insufficient tokens. Required: $required KES');
}

class TransactionFailedException extends AppException {
  const TransactionFailedException(String reason)
      : super('Transaction failed: $reason');
}

class DuplicateTransactionException extends AppException {
  const DuplicateTransactionException()
      : super('Duplicate transaction detected');
}

// USSD Exceptions
class UssdException extends AppException {
  const UssdException(String message) : super(message);
}

class UssdTimeoutException extends UssdException {
  const UssdTimeoutException() : super('USSD timeout');
}

class UssdMenuMismatchException extends UssdException {
  const UssdMenuMismatchException() : super('USSD menu mismatch');
}

class UssdAnomalyException extends UssdException {
  const UssdAnomalyException() : super('USSD anomaly detected');
}

// Payment Exceptions
class PaymentException extends AppException {
  const PaymentException(String message) : super(message);
}

class PaymentPendingException extends PaymentException {
  const PaymentPendingException() : super('Payment pending confirmation');
}

class PaymentFailedException extends PaymentException {
  const PaymentFailedException() : super('Payment failed');
}

// Local Storage Exceptions
class StorageException extends AppException {
  const StorageException(String message) : super(message);
}

class EncryptionException extends StorageException {
  const EncryptionException(String message) : super(message);
}

// Device Exceptions
class RootedDeviceException extends AppException {
  const RootedDeviceException() 
      : super('App cannot run on rooted/jailbroken devices');
}

class BiometricException extends AppException {
  const BiometricException(String message) : super(message);
}