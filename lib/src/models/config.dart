import 'package:customer_io/customer_io_config.dart' as cio_config;
import '../constants/endpoints.dart';

/// Region enum for CDP API endpoints
enum Region {
  /// US region
  us,

  /// EU region
  eu,

  /// AP region
  ap,
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

/// Customer.io configuration
class CustomerIoConfig {
  /// Customer.io site ID
  final String siteId;

  /// Customer.io API key
  final String apiKey;

  /// Customer.io region
  final String region;

  /// Whether to automatically track device attributes
  final bool autoTrackDeviceAttributes;

  /// Push notification configuration for Android
  final cio_config.PushConfig? pushConfig;

  /// In-app message configuration
  final cio_config.InAppConfig? inAppConfig;

  /// Migration site ID
  final String? migrationSiteId;

  const CustomerIoConfig({
    required this.siteId,
    required this.apiKey,
    this.region = 'us',
    this.autoTrackDeviceAttributes = true,
    this.pushConfig,
    this.inAppConfig,
    this.migrationSiteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      'apiKey': apiKey,
      'region': region,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'pushConfig': pushConfig?.toMap(),
      'inAppConfig': inAppConfig?.toMap(),
      'migrationSiteId': migrationSiteId,
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
    return CDPEndpoints.defaultBaseUrl;
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
