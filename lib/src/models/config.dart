import '../constants/endpoints.dart';
import '../utils/cdp_gateway_urls.dart';

// Region enum for CDP API endpoints
enum Region {
  /// US region
  us,

  /// EU region
  eu,
}

/// Log level for SDK debugging
enum OpenCDPLogLevel {
  /// No logging
  none,

  /// Error level logging
  error,

  /// Warning level logging
  warn,

  /// Info level logging
  info,

  /// Debug level logging
  debug,
}

/// Screen view tracking configuration
enum ScreenView {
  /// Disable screen view tracking
  none,

  /// Track all screen views
  all,

  /// Track only manually tracked screen views
  manual,
}

/// Enum to define the log levels.
/// Logs can be viewed in Xcode or Android studio.
enum CioLogLevel { none, error, info, debug }

/// Enum to specify the type of metric for tracking
// enum MetricEvent { delivered, opened, converted }

/// Enum to specify the click behavior of push notification for Android
enum PushClickBehaviorAndroid {
  resetTaskStack(rawValue: 'RESET_TASK_STACK'),
  activityPreventRestart(rawValue: 'ACTIVITY_PREVENT_RESTART'),
  activityNoFlags(rawValue: 'ACTIVITY_NO_FLAGS');

  factory PushClickBehaviorAndroid.fromValue(String value) {
    switch (value) {
      case 'RESET_TASK_STACK':
        return PushClickBehaviorAndroid.resetTaskStack;
      case 'ACTIVITY_PREVENT_RESTART':
        return PushClickBehaviorAndroid.activityPreventRestart;
      case 'ACTIVITY_NO_FLAGS':
        return PushClickBehaviorAndroid.activityNoFlags;
      default:
        throw ArgumentError('Invalid value provided');
    }
  }

  const PushClickBehaviorAndroid({
    required this.rawValue,
  });

  final String rawValue;
}

/// Customer.io configuration
// String? migrationSiteId,
// Region? region,
// CioLogLevel? logLevel,
// bool? autoTrackDeviceAttributes,
// bool? trackApplicationLifecycleEvents,
// String? apiHost,
// String? cdnHost,
// int? flushAt,
// int? flushInterval,
// ScreenView? screenViewUse,
// InAppConfig? inAppConfig,
// PushConfig? pushConfig,

class CustomerIoConfig {
  /// Customer.io site ID
  final String siteId;

  /// Customer.io API key
  final String apiKey;

  /// Customer.io region
  final Region customerIoRegion;

  /// Whether to automatically track device attributes
  final bool autoTrackDeviceAttributes;

  /// Push notification configuration for Android
  final PushConfig? pushConfig;

  /// In-app message configuration
  final InAppConfig? inAppConfig;

  /// Migration site ID
  final String? migrationSiteId;

  /// Log level
  final OpenCDPLogLevel? logLevel;

  /// Whether to automatically track screens
  final bool? autoTrackScreens;

  /// Whether to track application lifecycle events
  final bool? trackApplicationLifecycleEvents;

  /// Screen view tracking configuration
  final ScreenView? screenViewUse;

  const CustomerIoConfig({
    required this.siteId,
    required this.apiKey,
    required this.customerIoRegion,
    this.autoTrackDeviceAttributes = true,
    this.pushConfig,
    this.inAppConfig,
    this.migrationSiteId,
    this.logLevel,
    this.autoTrackScreens,
    this.trackApplicationLifecycleEvents,
    this.screenViewUse,
  });

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      'apiKey': apiKey,
      'region': customerIoRegion,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'pushConfig': pushConfig?.toMap(),
      'inAppConfig': inAppConfig?.toMap(),
      'migrationSiteId': migrationSiteId,
      'logLevel': logLevel?.toString().split('.').last,
      'autoTrackScreens': autoTrackScreens,
      'trackApplicationLifecycleEvents': trackApplicationLifecycleEvents,
      'screenViewUse': screenViewUse?.toString().split('.').last,
    };
  }
}

/// Main configuration class for Open CDP SDK
class OpenCDPConfig {
  /// CDP API Key
  final String cdpApiKey;

  /// iOS App Group(required for push notification tracking on iOS)
  /// If not provided, background push tracking may fail for iOS.
  final String? iOSAppGroup;

  /// Optional custom CDP endpoint (primary gateway root).
  final String? cdpEndpoint;

  /// Optional backup gateway roots. When omitted, the SDK uses
  /// [CDPEndpoints.backupBaseUrlXyz] and [CDPEndpoints.backupBaseUrlCom].
  final List<String>? cdpFallbackEndpoints;

  /// Max time to wait for a single CDP gateway HTTP exchange (POST/GET).
  /// Clamped to 5s..120s. Defaults to 30 seconds.
  final Duration cdpRequestTimeout;

  /// Whether to send events to Customer.io
  final bool sendToCustomerIo;

  /// Customer.io configuration
  final CustomerIoConfig? customerIo;

  /// Whether to enable debug logging
  final bool debug;

  /// Whether to automatically track device attributes
  final bool autoTrackDeviceAttributes;

  /// Whether to automatically track screens
  final bool autoTrackScreens;

  /// Whether to track application lifecycle events
  final bool trackApplicationLifecycleEvents;

  /// Screen view tracking configuration.
  ///
  /// **Deprecated:** Not read by the SDK; use [autoTrackScreens] instead.
  @Deprecated('Not implemented; use autoTrackScreens instead')
  final ScreenView screenViewUse;

  /// Whether the SDK should automatically deliver in-app messages on
  /// [CDPInAppManager.messageStream]. When `true`, the manager starts after
  /// [initialize] and binds to the user after [OpenCDPSDK.identify].
  final bool enableInAppMessages;

  /// Whether to use low-latency automatic in-app delivery. Only takes effect
  /// when [enableInAppMessages] is also `true`. Defaults to `true`.
  final bool enableInAppRealtime;

  /// Interval between background message checks when [enableInAppRealtime] is
  /// `false`, or while automatic delivery is recovering. Defaults to 30 seconds.
  final Duration inAppPollInterval;

  /// How long to wait without new data before retrying automatic delivery.
  /// Defaults to 60 seconds.
  final Duration inAppRealtimeStaleTimeout;

  /// Maximum delay between automatic delivery retries. Defaults to 30 seconds.
  final Duration inAppRealtimeMaxBackoff;

  /// Maximum messages requested per sync (1..50). Defaults to 10.
  final int inAppSyncLimit;

  /// Optional override for the platform value sent to the backend.
  /// Defaults to `ios`/`android`/`web` based on the runtime.
  final String? inAppPlatformOverride;

  /// Optional override for the app version string sent to the backend.
  /// If omitted, the SDK leaves it blank.
  final String? inAppAppVersionOverride;

  /// Whether to throw errors back to the caller for handling.
  ///
  /// When `true`:
  /// - Validation errors throw [CDPValidationException] (works in both debug and prod)
  /// - API errors throw [CDPException] (works in both debug and prod)
  /// - Customer.io errors are rethrown (works in both debug and prod)
  /// - Users must handle these exceptions in their code
  ///
  /// When `false` (default):
  /// - Errors are only logged when `debug` is `true` (debug mode only)
  /// - No errors are thrown in production
  /// - Methods return silently on errors
  ///
  /// This allows users to choose between:
  /// - Strict error handling: `throwErrorsBack: true` - catch and handle all errors
  /// - Silent error handling: `throwErrorsBack: false` - errors are logged but don't interrupt flow
  final bool throwErrorsBack;

  /// Primary gateway base URL for API endpoints.
  String get baseUrl {
    if (cdpEndpoint != null && cdpEndpoint!.trim().isNotEmpty) {
      return CdpGatewayUrls.normalizeBaseUrl(cdpEndpoint!);
    }
    return CDPEndpoints.baseUrl;
  }

  /// Primary plus backup gateway URLs. Every request tries these in order,
  /// starting at [baseUrl] on each new call.
  List<String> get allBaseUrls => CdpGatewayUrls.resolveAllBaseUrls(
        primaryOverride: cdpEndpoint,
        fallbackOverrides: cdpFallbackEndpoints,
      );

  /// App Group ID (used for background push notification tracking)
  /// Returns iOSAppGroup on iOS, or a default value on Android
  String? get appGroup {
    return iOSAppGroup;
  }

  OpenCDPConfig({
    required this.cdpApiKey,
    this.iOSAppGroup,
    this.cdpEndpoint,
    this.cdpFallbackEndpoints,
    Duration? cdpRequestTimeout,
    this.sendToCustomerIo = false,
    this.customerIo,
    this.debug = false,
    this.autoTrackDeviceAttributes = true,
    this.autoTrackScreens = false,
    this.trackApplicationLifecycleEvents = true,
    this.screenViewUse = ScreenView.all,
    this.enableInAppMessages = false,
    this.enableInAppRealtime = true,
    this.inAppPollInterval = const Duration(seconds: 30),
    this.inAppRealtimeStaleTimeout = const Duration(seconds: 60),
    this.inAppRealtimeMaxBackoff = const Duration(seconds: 30),
    this.inAppSyncLimit = 10,
    this.inAppPlatformOverride,
    this.inAppAppVersionOverride,
    this.throwErrorsBack = false,
  }) : cdpRequestTimeout = CdpGatewayUrls.clampRequestTimeout(
          cdpRequestTimeout ?? CdpGatewayUrls.defaultRequestTimeout,
        );

  Map<String, dynamic> toMap() {
    return {
      'cdpApiKey': cdpApiKey,
      'cdpEndpoint': cdpEndpoint,
      'cdpFallbackEndpoints': cdpFallbackEndpoints,
      'cdpRequestTimeoutMs': cdpRequestTimeout.inMilliseconds,
      'baseUrl': baseUrl,
      'allBaseUrls': allBaseUrls,
      'iOSAppGroup': appGroup,
      'sendToCustomerIo': sendToCustomerIo,
      'customerIo': customerIo?.toMap(),
      'debug': debug,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'autoTrackScreens': autoTrackScreens,
      'throwErrorsBack': throwErrorsBack,
      'trackApplicationLifecycleEvents': trackApplicationLifecycleEvents,
      'screenViewUse': screenViewUse.toString().split('.').last,
      'enableInAppMessages': enableInAppMessages,
      'enableInAppRealtime': enableInAppRealtime,
      'inAppPollIntervalSeconds': inAppPollInterval.inSeconds,
      'inAppRealtimeStaleTimeoutSeconds': inAppRealtimeStaleTimeout.inSeconds,
      'inAppRealtimeMaxBackoffMs': inAppRealtimeMaxBackoff.inMilliseconds,
      'inAppSyncLimit': inAppSyncLimit,
      'inAppPlatformOverride': inAppPlatformOverride,
      'inAppAppVersionOverride': inAppAppVersionOverride,
    };
  }
}

class PushConfig {
  PushConfigAndroid pushConfigAndroid;

  PushConfig({PushConfigAndroid? android})
      : pushConfigAndroid = android ?? PushConfigAndroid();

  Map<String, dynamic> toMap() {
    return {
      'android': pushConfigAndroid.toMap(),
    };
  }
}

class PushConfigAndroid {
  PushClickBehaviorAndroid pushClickBehavior;

  PushConfigAndroid(
      {this.pushClickBehavior =
          PushClickBehaviorAndroid.activityPreventRestart});

  Map<String, dynamic> toMap() {
    return {
      'pushClickBehavior': pushClickBehavior.rawValue,
    };
  }
}

class InAppConfig {
  final String siteId;

  InAppConfig({required this.siteId});

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
    };
  }
}
