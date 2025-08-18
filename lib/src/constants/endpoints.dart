/// API endpoints for the Open CDP SDK
class CDPEndpoints {
  /// Base URL for the CDP API
  static const String baseUrl = 'https://api.opencdp.io/gateway/data-gateway';

  static const String version = '/v1';

  /// Identify a person
  static const String identify = '$version/persons/identify';

  /// Track an event
  static const String track = '$version/persons/track';

  /// Update person properties
  static const String update = '$version/persons/update';

  /// Register device token
  static const String registerDevice = '$version/persons/registerDevice';
}
