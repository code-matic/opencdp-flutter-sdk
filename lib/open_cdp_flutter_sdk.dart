import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_manager.dart';
import 'package:open_cdp_flutter_sdk/src/initialization/sdk_initializer.dart';
import 'package:open_cdp_flutter_sdk/src/integrations/customer_io_integration.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_tracker.dart';

export 'src/in_app/in_app_manager.dart';
export 'src/models/config.dart';
export 'src/models/in_app_message.dart';
export 'src/models/metric_event.dart';
export 'src/models/validation_exception.dart';
export 'src/utils/http_client.dart' show CDPException;
export 'src/utils/push_notification_payload.dart';

String? _effectivePushActionId(
  Map<String, dynamic> data,
  String? tappedActionId,
) {
  final fromArg = tappedActionId?.trim();
  if (fromArg != null && fromArg.isNotEmpty) return fromArg;
  for (final key in ['action_id', 'action_clicked']) {
    final raw = data[key];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  }
  return null;
}

/// Mask an API key for log output. Keeps the last 6 characters so adopters
/// can still distinguish keys when debugging, but never echoes the full
/// value to logcat/console (which would leak the credential to anyone with
/// device-log access on a non-release build, and to anyone scraping logs
/// in test/staging environments where `debug: true` is the default).
String _maskApiKeyForLog(String value) {
  if (value.isEmpty) return value;
  if (value.length <= 6) return '***';
  return '***${value.substring(value.length - 6)}';
}

/// Build a copy of [OpenCDPConfig.toMap] with credential fields redacted.
/// Today the CDP `cdpApiKey` and the nested Customer.io `apiKey` are both
/// raw API keys; everything else in the map is non-sensitive configuration
/// (endpoints, feature flags, durations) and is safe to log verbatim.
Map<String, dynamic> _redactConfigForLogging(Map<String, dynamic> raw) {
  final masked = Map<String, dynamic>.from(raw);
  final cdpKey = masked['cdpApiKey'];
  if (cdpKey is String) {
    masked['cdpApiKey'] = _maskApiKeyForLog(cdpKey);
  }
  final cio = masked['customerIo'];
  if (cio is Map) {
    final maskedCio = Map<String, dynamic>.from(cio.cast<String, dynamic>());
    final cioKey = maskedCio['apiKey'];
    if (cioKey is String) {
      maskedCio['apiKey'] = _maskApiKeyForLog(cioKey);
    }
    masked['customerIo'] = maskedCio;
  }
  return masked;
}

/// Main SDK class for Open CDP
class OpenCDPSDK {
  static OpenCDPSDK? _instance;
  static OpenCDPSDKImplementation? _implementation;
  static CDPScreenTracker? _screenTracker;
  static CDPLifecycleTracker? _lifecycleTracker;
  static CDPInAppManager? _inAppManager;

  /// Get the singleton instance of the SDK
  static OpenCDPSDK get instance {
    if (_instance == null) {
      // Log error but return dummy instance to prevent crashes
      debugPrint(
          '[CDP] ERROR: SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return OpenCDPSDK._();
    }
    return _instance!;
  }

  /// Get the current user ID
  String? get userId => _implementation?.userId;

  /// Get the screen tracker if auto tracking is enabled
  CDPScreenTracker? get screenTracker => _screenTracker;

  /// Access to the in-app message manager. Always available after `initialize`,
  /// but only auto-polls when `OpenCDPConfig.enableInAppMessages` is true.
  CDPInAppManager? get inApp => _inAppManager;

  /// Reset the SDK instance (for testing purposes)
  @visibleForTesting
  static Future<void> resetForTest() async {
    if (_instance != null) {
      _instance!.dispose();
    }

    // Reset static variables in implementation
    OpenCDPSDKImplementation.resetStaticVariables();

    // Reset all instance variables
    _instance = null;
    _implementation = null;
    _screenTracker = null;
    _lifecycleTracker = null;

    debugPrint('[CDP] SDK reset for testing');
  }

  /// Initialize the SDK with configuration
  ///
  /// **REQUIRED**: This method must be called before using any SDK functionality.
  /// The SDK will not work properly if this method is not called.
  ///
  /// shouldReinitialize: If true, allows re-initialization of the SDK
  /// this is useful for testing purposes and also if you need to change config at runtime
  ///
  /// [httpClient] is for testing only and should not be used in production.
  static Future<void> initialize({
    required OpenCDPConfig config,
    bool shouldReinitialize = false,
    @visibleForTesting CDPHttpClient? httpClient,
  }) async {
    try {
      if (_instance != null && shouldReinitialize == false) {
        if (config.debug) {
          debugPrint('[CDP] SDK already initialized');
        }
        return;
      } else {
        if (_instance != null && shouldReinitialize == true) {
          // Full cleanup of previous instance before reinitializing
          await _fullCleanup(config);
        }

        debugPrint('[CDP] Initializing SDK...');
        debugPrint('[CDP] Config: ${_redactConfigForLogging(config.toMap())}');

        // Reset implementation's static variables if reinitializing
        if (shouldReinitialize) {
          OpenCDPSDKImplementation.resetStaticVariables();
          debugPrint('[CDP] Reset static variables for reinitialization');
        }

        // Create new instance
        _instance = OpenCDPSDK._();
        _implementation = await OpenCDPSDKImplementation.create(
            config: config, httpClient: httpClient);

        // Initialize SDK components
        _screenTracker = await SDKInitializer.initialize(
          config: config,
          sdk: _instance!,
          implementation: _implementation!,
        );

        _lifecycleTracker = SDKInitializer.initializeLifecycleTracker(
          config: config,
          sdk: _instance!,
        );

        // In-app manager is always created so manual sync/track APIs work; it
        // only auto-polls when enableInAppMessages is true.
        _inAppManager = SDKInitializer.initializeInAppManager(
          config: config,
          implementation: _implementation!,
        );

        // Bridge auto screen tracking → in-app screen filter so backend page
        // rules apply automatically as the user navigates.
        _screenTracker?.onScreenChange = (screen) {
          _inAppManager?.setCurrentScreen(screen);
        };
      }
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error initializing SDK: $e');
      }
    }
  }

  /// Performs a full cleanup of all SDK resources for reinitialization
  static Future<void> _fullCleanup(OpenCDPConfig config) async {
    // 1. Clear any identity information first to ensure pending requests are flushed
    if (_implementation != null) {
      await _implementation!.clearIdentity();
    }

    // 2. Reset Customer.io integration
    try {
      if (config.sendToCustomerIo) {
        await CustomerIOIntegration.reset();
      }
    } catch (e) {
      debugPrint('[CDP] Error resetting Customer.io integration: $e');
    }

    // 3. Clear native API key and base URL storage if needed
    if (!kIsWeb) {
      try {
        final appGroup = config.iOSAppGroup ?? '';
        await NativeBridge.clearApiKeyFromNative(appGroup: appGroup);
        await NativeBridge.clearBaseUrlFromNative(appGroup: appGroup);
      } catch (e) {
        debugPrint('[CDP] Error clearing native API key: $e');
      }
    }

    // 4. Clean up push notification tracker resources
    try {
      PushNotificationTracker.dispose();
    } catch (e) {
      debugPrint('[CDP] Error disposing push notification tracker: $e');
    }

    // 5. Dispose the in-app manager (cancels polling, closes streams)
    try {
      _inAppManager?.dispose();
    } catch (e) {
      debugPrint('[CDP] Error disposing in-app manager: $e');
    }

    // 6. Dispose the current instance (this will release HTTP client resources)
    if (_instance != null) {
      _instance!.dispose();
    }

    // 7. Set instance variables to null
    _instance = null;
    _implementation = null;
    _screenTracker = null;
    _lifecycleTracker = null;
    _inAppManager = null;

    debugPrint('[CDP] Full SDK cleanup completed for reinitialization');
  }

  /// Private constructor
  OpenCDPSDK._();

  /// Identify a user with optional traits
  ///
  /// **Important:** The [identifier] must NOT be an email address.
  ///
  /// [identifier] - Unique user identifier (used for CDP API and native storage)
  /// [properties] - Optional user properties/traits
  /// [customerIoId] - Optional Customer.io-specific identifier.
  ///   Use this when you need to identify users with an email address in Customer.io
  ///   while maintaining a non-email identifier for CDP operations.
  ///
  /// Example with Customer.io dual-write:
  /// ```dart
  /// await OpenCDPSDK.instance.identify(
  ///   identifier: 'user_123',           // Non-email ID for CDP
  ///   customerIoId: 'user@example.com', // Email ID for Customer.io
  ///   properties: {'name': 'John Doe'},
  /// );
  /// ```
  Future<void> identify({
    required String identifier,
    Map<String, dynamic> properties = const {},
    String? customerIoId,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot identify user - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.identifyUser(
      identifier: identifier,
      properties: properties,
      customerIoId: customerIoId,
    );
    // Realtime in-app: rebind the SSE stream to the new identity so the
    // server pushes for the right `person_id`. No-op when in-app messaging
    // or realtime is disabled in config.
    await _inAppManager?.setActiveIdentity(_implementation!.userId);
  }

  /// Track an event with optional properties
  Future<void> track({
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track event - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackEvent(
      eventName: eventName,
      properties: properties,
    );
  }

  /// Update properties for a user
  // Future<void> update({
  //   required Map<String, dynamic> properties,
  // }) async {
  //   if (_implementation == null) {
  //     debugPrint(
  //         '[CDP] ERROR: Cannot update user properties - SDK not initialized. Call OpenCDPSDK.initialize() first.');
  //     return;
  //   }
  //   await _implementation!.updateUserProperties(
  //     properties: properties,
  //   );
  // }

  /// Register a device token for push notifications
  ///
  /// [fcmToken] is the Firebase Cloud Messaging token
  /// [apnToken] is the Apple Push Notification token
  ///
  /// This method is used to register a device token for push notifications
  ///
  Future<void> registerDeviceToken({
    String? fcmToken,
    String? apnToken,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot register device - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.registerDevice(
      fcmToken: fcmToken,
      apnToken: apnToken,
    );
  }

  /// Track a lifecycle event
  Future<void> trackLifecycleEvent({
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track lifecycle event - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackLifecycleEvent(
      eventName: eventName,
      properties: properties,
    );
  }

  /// Track a screen view
  Future<void> trackScreenView({
    required String title,
    Map<String, dynamic> properties = const {},
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track screen view - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackScreenView(
      title: title,
      properties: properties,
    );
  }

  /// Sync in-app messages for the current person and context.
  Future<List<InAppMessage>> syncInAppMessages({
    required String screen,
    required String platform,
    String? appVersion,
    int limit = 10,
    String? personId,
    int? tzOffsetMinutes,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot sync in-app messages - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return [];
    }
    return _implementation!.syncInAppMessages(
      screen: screen,
      platform: platform,
      appVersion: appVersion,
      limit: limit,
      personId: personId,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  /// Track in-app message impression.
  Future<void> trackInAppImpression({
    required String deliveryId,
    required String screen,
    required String platform,
    String? appVersion,
    String? personId,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track in-app impression - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackInAppImpression(
      deliveryId: deliveryId,
      screen: screen,
      platform: platform,
      appVersion: appVersion,
      personId: personId,
    );
  }

  /// Track in-app message click.
  Future<void> trackInAppClick({
    required String deliveryId,
    required String actionId,
    required String screen,
    String? personId,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track in-app click - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackInAppClick(
      deliveryId: deliveryId,
      actionId: actionId,
      screen: screen,
      personId: personId,
    );
  }

  /// Track in-app message dismiss.
  Future<void> trackInAppDismiss({
    required String deliveryId,
    required String reason,
    required String screen,
    String? personId,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track in-app dismiss - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.trackInAppDismiss(
      deliveryId: deliveryId,
      reason: reason,
      screen: screen,
      personId: personId,
    );
  }

  /// Handles a delivered push notification when app is in foreground
  static Future<void> handleForegroundPushDelivery(
      Map<String, dynamic> data) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track foreground push delivery - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    final deliveryMessageId = data['delivery_message_id'] as String?;
    if (deliveryMessageId == null || deliveryMessageId.isEmpty) {
      debugPrint(
          '[CDP] No delivery_message_id found in foreground push payload.');
      return;
    }
    final deliverySendContextId = data['delivery_send_context_id'] ?? "";
    final deliverySendContext = data['delivery_send_context'] ?? "";

    await _implementation!.trackPushNotificationMetric(
      MetricEvent.delivered,
      deliveryMessageId,
      false,
      deliverySendContext,
      deliverySendContextId,
    );
  }

  /// Handles a delivered push notification when app is in background
  static Future<void> handleBackgroundPushDelivery(
      Map<String, dynamic> data) async {
    final deliveryMessageId = data['delivery_message_id'] as String?;
    if (deliveryMessageId == null || deliveryMessageId.isEmpty) {
      debugPrint(
          '[CDP] No delivery_message_id found in background push payload.');
      return;
    }
    final deliverySendContextId = data['delivery_send_context_id'] ?? "";
    final deliverySendContext = data['delivery_send_context'] ?? "";

    // Get API key from instance if initialized, otherwise null and will rely on native storage
    String? apiKey;
    String? appGroup;

    // Check if SDK is initialized and grab config values if available
    if (_implementation != null) {
      apiKey = _implementation!.config.cdpApiKey;
      appGroup = _implementation!.config.appGroup;
      debugPrint(
          '[CDP] Using SDK instance API key for background push tracking');
    } else {
      debugPrint(
          '[CDP] SDK not initialized, will try to use stored API key for background push tracking');
    }

    await OpenCDPSDKImplementation.trackBackgroundPushNotificationMetric(
      MetricEvent.delivered,
      deliveryMessageId,
      deliverySendContext,
      deliverySendContextId,
      true, // This is a background event
      apiKeyOverride: apiKey,
      baseUrlOverride: _implementation?.config.baseUrl,
      appGroup: appGroup,
    );
  }

  /// Android-only helper to render a notification with action buttons using
  /// native `NotificationCompat` APIs from push `data` payload.
  ///
  /// Useful in `FirebaseMessaging.onBackgroundMessage` when actionable pushes
  /// are sent as data-focused messages and must be displayed by the app.
  static Future<bool> showAndroidActionableNotification(
    Map<String, dynamic> data, {
    String channelName = 'CDP Notifications',
    String channelDescription = 'Push notifications from CDP',
  }) async {
    return NativeBridge.showAndroidActionableNotification(
      data: data,
      channelName: channelName,
      channelDescription: channelDescription,
    );
  }

  /// Handles when the user opens a push notification (body tap) or taps an
  /// action button (push v2).
  ///
  /// Pass [action_clicked] with the tapped button's `action_id` when the user
  /// tapped a notification action. You can also set `action_id` or
  /// `action_clicked` on [data] (string values). If any of these is non-empty,
  /// the SDK reports `status: clicked` with `props: { "action_id": "..." }` on
  /// the delivery endpoint.
  static Future<void> handlePushNotificationOpen(
    Map<String, dynamic> data, {
    // ignore: non_constant_identifier_names — named argument aligns with delivery payload keys
    String? action_clicked,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot track push open - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    final deliveryMessageId = data['delivery_message_id'] as String?;
    if (deliveryMessageId == null || deliveryMessageId.isEmpty) {
      debugPrint('[CDP] No delivery_message_id found in opened push payload.');
      return;
    }

    final deliverySendContextId = data['delivery_send_context_id'] ?? "";
    final deliverySendContext = data['delivery_send_context'] ?? "";

    final resolvedActionId = _effectivePushActionId(data, action_clicked);
    final isActionClick = resolvedActionId != null;

    await _implementation!.trackPushNotificationMetric(
      isActionClick ? MetricEvent.actionClicked : MetricEvent.opened,
      deliveryMessageId,
      false,
      '$deliverySendContext',
      '$deliverySendContextId',
      actionId: isActionClick ? resolvedActionId : null,
    );
  }

  /// Clear the current identity and flush all pending requests
  ///
  /// This method:
  /// - Clears any stored user identity
  /// - Flushes all pending requests in the queue
  /// - Clears persistent storage
  /// - Returns immediately without making any network requests
  Future<void> clearIdentity() async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot clear identity - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    // Tear down the realtime stream first so we don't keep an authenticated
    // SSE connection open under the previous identity while the server-side
    // identity is changing out from under us.
    await _inAppManager?.setActiveIdentity(null);
    await _implementation!.clearIdentity();
  }

  /// Dispose the SDK instance
  void dispose() {
    if (_implementation != null) {
      _implementation!.dispose();
      _implementation = null;
    }

    // Remove lifecycle tracker if exists
    if (_lifecycleTracker != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleTracker!);
      _lifecycleTracker = null;
    }

    // Clean up screen tracker
    _screenTracker?.dispose();
    _screenTracker = null;

    // Stop in-app polling and release stream
    _inAppManager?.dispose();
    _inAppManager = null;
  }

  /// For testing: inject a mock/test HTTP client into the implementation
  @visibleForTesting
  static void setHttpClientForTest(dynamic client) {
    _implementation?.setHttpClient(client);
  }
}
