// lib/core/utils/ussd_template_formatter.dart
// W1 new utility.
//
// Two responsibilities, kept separate per Q2:
//   - UssdTemplateFormatter.format(): pure substitution (BH → phone, AMT → amount)
//     Matches Hybrid's FormatUssdUseCase exactly (decompile-verified).
//   - normalizeKenyanPhone(): strip non-digits then '0' + digits.takeLast(9).
//     Matches Hybrid's logic with one cleanup over the original (whitespace/
//     dashes stripped before length check — Q1 lock).
//
// The W2 Quick Dial flow is responsible for:
//   1. Validating raw user input (empty / too short / no offer selected),
//   2. Calling normalizeKenyanPhone() to canonicalize,
//   3. Passing the result + the offer's ussdTemplate to UssdTemplateFormatter.format().
//
// Tests live in test/core/utils/ussd_template_formatter_test.dart.

/// Pure-substitution USSD template formatter. No validation, no normalization.
/// Caller is responsible for both.
class UssdTemplateFormatter {
  const UssdTemplateFormatter._();

  /// Substitutes the BH placeholder with [phone] and AMT (if present) with
  /// [amount]. Returns the template unchanged if neither placeholder is present.
  ///
  /// Multiple BH or AMT occurrences are all substituted (matches Hybrid's
  /// String.replace() default behavior).
  static String format(
    String template, {
    required String phone,
    int amount = 0,
  }) {
    return template
        .replaceAll('BH', phone)
        .replaceAll('AMT', amount.toString());
  }
}

/// Canonicalizes a Kenyan phone number to local 10-digit format starting with 0.
///
/// Behaviour:
///   1. Strip every non-digit character (whitespace, dashes, parens, '+').
///   2. Take the last 9 digits.
///   3. Prepend '0'.
///
/// Throws [ArgumentError] if the input has fewer than 9 digits after stripping.
///
/// Examples:
///   '0712345678'      → '0712345678'
///   '254712345678'    → '0712345678'
///   '+254712345678'   → '0712345678'
///   '712345678'       → '0712345678'
///   '0112345678'      → '0112345678'
///   '0712 345 678'    → '0712345678'
///   '0712-345-678'    → '0712345678'
String normalizeKenyanPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 9) {
    throw ArgumentError(
      'normalizeKenyanPhone: input must contain at least 9 digits after '
      'stripping non-digit characters (got "$raw" → "$digits")',
    );
  }
  return '0${digits.substring(digits.length - 9)}';
}