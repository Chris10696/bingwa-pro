import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 2,
  );
  
  static final NumberFormat _compactCurrency = NumberFormat.compactCurrency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 2,
  );
  
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  
  // Currency formatting
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }
  
  static String formatCompactCurrency(double amount) {
    return _compactCurrency.format(amount);
  }
  
  // Date formatting
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
  
  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }
  
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }
  
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return formatDate(dateTime);
    }
  }
  
  // Phone number formatting
  static String formatPhoneNumber(String phone) {
    if (phone.startsWith('+254')) {
      return phone;
    } else if (phone.startsWith('0')) {
      return '+254${phone.substring(1)}';
    } else if (phone.startsWith('254')) {
      return '+$phone';
    } else if (phone.length == 9) {
      return '+254$phone';
    }
    return phone;
  }
  
  static String maskPhoneNumber(String phone) {
    if (phone.length < 7) return phone;
    
    final visibleDigits = 4;
    final maskedDigits = phone.length - visibleDigits - 3;
    
    final prefix = phone.substring(0, 3);
    final suffix = phone.substring(phone.length - visibleDigits);
    
    return '$prefix${'*' * maskedDigits}$suffix';
  }
  
  // Token formatting
  static String formatTokens(double tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toStringAsFixed(2);
  }
  
  // Percentage formatting
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
  
  // File size formatting
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  
  // Transaction reference formatting
  static String formatReference(String reference) {
    if (reference.length <= 8) return reference;
    return '${reference.substring(0, 4)}...${reference.substring(reference.length - 4)}';
  }
}