/// API endpoints for the Open CDP SDK
class CDPEndpoints {
  /// Base URL for the CDP API
  static const String baseUrl =
      'https://cdp-data-gateway-749119130796.europe-west1.run.app/data-gateway';

  /// production url
// https://api.opencdp.io/gateway/data-gateway/v1 //

  /// staging url
// https://cdp-data-gateway-prod1-81240184175.europe-west1.run.app/data-gateway/v1 //
  static const String version = '/v1';

  /// Identify a person
  static const String identify = '$version/persons/identify';

  /// Track an event
  static const String track = '$version/persons/track';

  /// Update person properties
  // static const String update = '$version/persons/update';

  /// Register device token
  static const String registerDevice = '$version/persons/registerDevice';

  /// push notification metrics
  static const String notificationMetrics = '$version/message/delivery/push';
}
