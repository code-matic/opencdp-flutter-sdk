/// Custom exception for CDP validation errors.
///
/// This exception is thrown when validation fails and `throwErrorsBack` is enabled
/// in the SDK configuration. It extends [ArgumentError] to provide better error
/// context and type safety, making it easier for users to catch specific validation errors.
class CDPValidationException extends ArgumentError {
  /// The field that failed validation (e.g., 'identifier', 'eventName').
  final String? field;

  /// Creates a new [CDPValidationException].
  ///
  /// [message] is the error message describing the validation failure.
  /// [field] is an optional field name that failed validation.
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

