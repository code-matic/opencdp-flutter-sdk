/// API endpoints for the Open CDP SDK
class CDPEndpoints {
  /// Base URL for the CDP API (primary).
  static const String baseUrl = 'https://api.opencdp.io/gateway/data-gateway';

  /// Backup gateway hosts used when the primary returns non-2xx or is unreachable.
  static const String backupBaseUrlXyz =
      'https://opencdp.xyz/gateway/data-gateway';

  static const String backupBaseUrlCom =
      'https://opencdp.com/gateway/data-gateway';

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

  /// In-app message sync
  static const String inAppSync = '$version/in-app/messages/sync';

  /// In-app realtime SSE stream. The server pushes lightweight `sync`
  /// events; the SDK reacts by hitting [inAppSync] to fetch eligible
  /// messages — eligibility lives server-side in one place.
  static const String inAppStream = '$version/in-app/messages/stream';

  /// In-app interactions
  static String inAppImpression(String deliveryId) =>
      '$version/in-app/messages/$deliveryId/impression';
  static String inAppClick(String deliveryId) =>
      '$version/in-app/messages/$deliveryId/click';
  static String inAppDismiss(String deliveryId) =>
      '$version/in-app/messages/$deliveryId/dismiss';
}
