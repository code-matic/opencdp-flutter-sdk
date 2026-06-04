/// Custom exception class for validation errors in the CDP SDK.
///
/// This exception is thrown when user-provided data fails validation checks,
/// such as empty identifiers, invalid email formats, or missing required fields.
///
/// The exception includes an optional [field] parameter to identify which
/// field failed validation, making it easier to provide specific error messages
/// to users.
class CDPValidationException extends ArgumentError {
  /// The field that failed validation (optional)
  final String? field;

  /// Creates a validation exception with a message and optional field name
  ///
  /// [message] describes what validation failed
  /// [field] identifies which field failed validation
  CDPValidationException(super.message, [this.field]);

  @override
  String toString() {
    final buffer = StringBuffer('CDPValidationException: $message');
    if (field != null) {
      buffer.write(' (field: $field)');
    }
    return buffer.toString();
  }
}

