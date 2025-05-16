/// API endpoints for the Open CDP SDK
class CDPEndpoints {
  /// Base URL for the CDP API
  static const String defaultBaseUrl =
      'https://cdp-data-gateway-749119130796.europe-west1.run.app/data-gateway';

  /// Identify a person
  static const String identify = '/v1/persons/identify';

  /// Track an event
  static const String track = '/v1/persons/track';

  /// Update person properties
  static const String update = '/v1/persons/update';

  /// Register device token
  static const String deviceToken = '/v1/persons/device-token';
}
