import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/initialization/sdk_initializer.dart';
import 'package:open_cdp_flutter_sdk/src/integrations/customer_io_integration.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';

export 'src/models/config.dart';
export 'src/models/validation_exception.dart';
export 'src/utils/http_client.dart' show CDPException;

/// Main SDK class for Open CDP
///
/// This class provides the primary interface for interacting with the Open CDP SDK.
/// It uses a singleton pattern, so you should access it via [OpenCDPSDK.instance].
///
/// Before using any other methods, you must call [initialize] with a valid [OpenCDPConfig].
class OpenCDPSDK {
  static OpenCDPSDK? _instance;
  static OpenCDPSDKImplementation? _implementation;
  static CDPScreenTracker? _screenTracker;
  static CDPLifecycleTracker? _lifecycleTracker;

  /// Get the singleton instance of the SDK.
  ///
  /// Returns a dummy instance if the SDK has not been initialized to prevent crashes,
  /// but logs an error to the console.
  static OpenCDPSDK get instance {
    if (_instance == null) {
      // Log error but return dummy instance to prevent crashes
      debugPrint(
          '[CDP] ERROR: SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return OpenCDPSDK._();
    }
    return _instance!;
  }

  /// Get the current user ID if one has been set via [identify].
  String? get userId => _implementation?.userId;

  /// Get the screen tracker instance if auto-tracking is enabled.
  ///
  /// This can be added to your [MaterialApp.navigatorObservers] to automatically
  /// track screen views.
  CDPScreenTracker? get screenTracker => _screenTracker;

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

  /// Initialize the SDK with the provided configuration.
  ///
  /// **REQUIRED**: This method must be called before using any other SDK functionality.
  ///
  /// [config] - The configuration object containing API keys and other settings.
  /// [shouldReinitialize] - If true, allows re-initialization of the SDK (useful for testing/runtime config changes).
  /// [httpClient] - Optional HTTP client for testing purposes.
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
        debugPrint('[CDP] Config: ${config.toMap()}');

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

    // 3. Clear native API key storage if needed
    if (!kIsWeb) {
      try {
        final appGroup = config.iOSAppGroup ?? '';
        await NativeBridge.clearApiKeyFromNative(appGroup: appGroup);
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

    // 5. Dispose the current instance (this will release HTTP client resources)
    if (_instance != null) {
      _instance!.dispose();
    }

    // 6. Set instance variables to null
    _instance = null;
    _implementation = null;
    _screenTracker = null;
    _lifecycleTracker = null;

    debugPrint('[CDP] Full SDK cleanup completed for reinitialization');
  }

  /// Private constructor
  OpenCDPSDK._();

  /// Identify a user with a unique identifier and optional properties.
  ///
  /// This links all future events to this user until [clearIdentity] is called.
  ///
  /// **Important:** The [identifier] must NOT be an email address.
  ///
  /// [identifier] - Unique user identifier (used for CDP API and native storage).
  /// [properties] - Optional map of user traits (e.g., name, plan).
  /// [customerIoId] - Optional Customer.io-specific identifier for dual-write scenarios.
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
  }

  /// Track a custom event.
  ///
  /// [eventName] - The name of the event (e.g., 'purchased_item').
  /// [properties] - Optional map of event properties (e.g., price, item_name).
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

  /// Register a device token for push notifications.
  ///
  /// [fcmToken] - The Firebase Cloud Messaging token (Android).
  /// [apnToken] - The Apple Push Notification token (iOS).
  ///
  /// This must be called to enable push notification tracking.
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

  /// Track a lifecycle event manually.
  ///
  /// **Note**: If [OpenCDPConfig.trackApplicationLifecycleEvents] is true,
  /// standard lifecycle events are tracked automatically.
  ///
  /// [eventName] - The name of the lifecycle event.
  /// [properties] - Optional properties for the event.
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

  /// Track a screen view manually.
  ///
  /// **Note**: If [OpenCDPConfig.autoTrackScreens] is true and [screenTracker]
  /// is added to Navigator observers, screen views are tracked automatically.
  ///
  /// [title] - The name of the screen.
  /// [properties] - Optional properties for the screen view.
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

  /// Handles a delivered push notification when app is in foreground.
  ///
  /// Call this method from your firebase_messaging `onMessage` handler.
  ///
  /// [data] - The data payload from the remote message.
  static Future<void> handleForegroundPushDelivery(
      Map<String, dynamic> data) async {
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

  /// Handles a delivered push notification when app is in background.
  ///
  /// Call this method from your firebase_messaging background handler.
  ///
  /// [data] - The data payload from the remote message.
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
      appGroup: appGroup,
    );
  }

  /// Handles when the user opens a push notification.
  ///
  /// Call this method when a notification is tapped.
  ///
  /// [data] - The data payload from the remote message.
  static Future<void> handlePushNotificationOpen(
      Map<String, dynamic> data) async {
    final deliveryMessageId = data['delivery_message_id'] as String?;
    if (deliveryMessageId == null || deliveryMessageId.isEmpty) {
      debugPrint('[CDP] No delivery_message_id found in opened push payload.');
      return;
    }

    final deliverySendContextId = data['delivery_send_context_id'] ?? "";
    final deliverySendContext = data['delivery_send_context'] ?? "";

    await _implementation!.trackPushNotificationMetric(
      MetricEvent.opened,
      deliveryMessageId,
      false,
      deliverySendContext,
      deliverySendContextId,
    );
  }

  /// Clear the current user identity and reset SDK state.
  ///
  /// This method:
  /// - Flushes any pending requests in the queue.
  /// - Clears the stored user ID.
  /// - Clears persistent storage related to identity.
  /// - Resets the SDK to an anonymous state.
  Future<void> clearIdentity() async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot clear identity - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.clearIdentity();
  }

  /// Dispose the SDK instance and cleanup resources.
  ///
  /// This should be called when the SDK is no longer needed or when the app is terminating.
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
  }

  /// For testing: inject a mock/test HTTP client into the implementation
  @visibleForTesting
  static void setHttpClientForTest(dynamic client) {
    _implementation?.setHttpClient(client);
  }
}
