/// API endpoints for the Open CDP SDK
class CDPEndpoints {
  /// Base URL for the CDP API
  static const String baseUrl =
      'https://cdp-data-gateway-749119130796.europe-west1.run.app/data-gateway';

  /// Identify a person
  static const String identify = '/persons/identify';

  /// Track an event
  static const String track = '/persons/track';

  /// Update person properties
  static const String update = '/persons/update';

  /// Register device token
  static const String registerDevice = '/persons/registerDevice';
}
