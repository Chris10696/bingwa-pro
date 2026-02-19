import '../constants/app_constants.dart';

class Validators {
  static String? isValidSafaricomNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Clean the number
    String cleaned = value.trim();
    
    // Remove spaces, dashes, etc.
    cleaned = cleaned.replaceAll(RegExp(r'[-\s]'), '');
    
    // Check if it starts with +254
    if (cleaned.startsWith('+254')) {
      cleaned = '0${cleaned.substring(4)}';
    }
    
    // Check if it starts with 254
    if (cleaned.startsWith('254')) {
      cleaned = '0${cleaned.substring(3)}';
    }
    
    // Validate Safaricom number pattern
    final regex = RegExp(AppConstants.safaricomRegex);
    if (!regex.hasMatch(cleaned)) {
      return 'Enter a valid Safaricom number (e.g., 0712345678)';
    }
    
    return null;
  }
  
  static String? isValidPin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    
    // Check length
    if (value.length != 4) {
      return 'PIN must be 4 digits';
    }
    
    // Check if all digits
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must contain only digits';
    }
    
    // Check for sequential numbers
    if (_isSequential(value)) {
      return 'Avoid sequential numbers (e.g., 1234)';
    }
    
    // Check for repeated numbers
    if (_isRepeated(value)) {
      return 'Avoid repeated numbers (e.g., 1111)';
    }
    
    return null;
  }
  
  static String? isValidAmount(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Enter a valid amount';
    }
    
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    
    if (min != null && amount < min) {
      return 'Minimum amount is ${min.toStringAsFixed(2)}';
    }
    
    if (max != null && amount > max) {
      return 'Maximum amount is ${max.toStringAsFixed(2)}';
    }
    
    return null;
  }
  
  static String? isValidFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }
    
    if (value.length < 3) {
      return 'Name is too short';
    }
    
    if (value.length > 100) {
      return 'Name is too long';
    }
    
    // Check for valid characters
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    
    return null;
  }
  
  static String? isValidNationalId(String? value) {
    if (value == null || value.isEmpty) {
      return 'National ID is required';
    }
    
    // Kenyan ID format: 8 digits
    if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
      return 'Enter a valid 8-digit National ID';
    }
    
    return null;
  }
  
  static String? isValidEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }
  
  static String? isValidAgentCode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Agent code is optional
    }
    
    // Alphanumeric, 6-12 characters
    if (!RegExp(r'^[a-zA-Z0-9]{6,12}$').hasMatch(value)) {
      return 'Agent code must be 6-12 alphanumeric characters';
    }
    
    return null;
  }
  
  static String? isValidPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }
  
  // Helper methods
  static bool _isSequential(String value) {
    final digits = value.split('').map(int.parse).toList();
    
    // Check ascending sequence
    bool ascending = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) {
        ascending = false;
        break;
      }
    }
    
    // Check descending sequence
    bool descending = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] - 1) {
        descending = false;
        break;
      }
    }
    
    return ascending || descending;
  }
  
  static bool _isRepeated(String value) {
    final firstChar = value[0];
    return value.split('').every((char) => char == firstChar);
  }
}