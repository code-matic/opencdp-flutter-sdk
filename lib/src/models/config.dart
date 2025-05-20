import '../constants/endpoints.dart';

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
enum MetricEvent { delivered, opened, converted }

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

  /// Optional custom CDP endpoint
  final String? cdpEndpoint;

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

  /// Screen view tracking configuration
  final ScreenView screenViewUse;

  /// Base URL for API endpoints
  String get baseUrl {
    if (cdpEndpoint != null) {
      return cdpEndpoint!;
    }
    return CDPEndpoints.baseUrl;
  }

  const OpenCDPConfig({
    required this.cdpApiKey,
    this.cdpEndpoint,
    this.sendToCustomerIo = false,
    this.customerIo,
    this.debug = false,
    this.autoTrackDeviceAttributes = true,
    this.autoTrackScreens = false,
    this.trackApplicationLifecycleEvents = true,
    this.screenViewUse = ScreenView.all,
  });

  Map<String, dynamic> toMap() {
    return {
      'cdpApiKey': cdpApiKey,
      'cdpEndpoint': cdpEndpoint,
      'baseUrl': baseUrl,
      'sendToCustomerIo': sendToCustomerIo,
      'customerIo': customerIo?.toMap(),
      'debug': debug,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'autoTrackScreens': autoTrackScreens,
      'trackApplicationLifecycleEvents': trackApplicationLifecycleEvents,
      'screenViewUse': screenViewUse.toString().split('.').last,
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
