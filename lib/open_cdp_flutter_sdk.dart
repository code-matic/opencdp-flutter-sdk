import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/initialization/sdk_initializer.dart';
import 'package:open_cdp_flutter_sdk/src/integrations/customer_io_integration.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_tracker.dart';

export 'src/models/config.dart';

/// Main SDK class for Open CDP
class OpenCDPSDK {
  static OpenCDPSDK? _instance;
  static OpenCDPSDKImplementation? _implementation;
  static CDPScreenTracker? _screenTracker;
  static CDPLifecycleTracker? _lifecycleTracker;

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

  /// Identify a user with optional traits
  Future<void> identify({
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot identify user - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.identifyUser(
      identifier: identifier,
      properties: properties,
    );
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

  /// Handles a delivered push notification when app is in foreground
  static Future<void> handleForegroundPushDelivery(
      Map<String, dynamic> data) async {
    final messageId = data['message_id'] as String?;
    if (messageId == null || messageId.isEmpty) {
      debugPrint('[CDP] No message_id found in foreground push payload.');
      return;
    }
    final sendContextId = data['send_context_id'] ?? "";
    final sendContext = data['send_context'] ?? "";

    await _implementation!.trackPushNotificationMetric(
      MetricEvent.delivered,
      messageId,
      false,
      sendContext,
      sendContextId,
    );
  }

  /// Handles a delivered push notification when app is in background
  static Future<void> handleBackgroundPushDelivery(
      Map<String, dynamic> data) async {
    final messageId = data['message_id'] as String?;
    if (messageId == null || messageId.isEmpty) {
      debugPrint('[CDP] No message_id found in background push payload.');
      return;
    }
    final sendContextId = data['send_context_id'] ?? "";
    final sendContext = data['send_context'] ?? "";

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
      messageId,
      sendContext,
      sendContextId,
      true, // This is a background event
      apiKeyOverride: apiKey,
      appGroup: appGroup,
    );
  }

  /// Handles when the user opens a push notification
  static Future<void> handlePushNotificationOpen(
      Map<String, dynamic> data) async {
    final messageId = data['message_id'] as String?;
    if (messageId == null || messageId.isEmpty) {
      debugPrint('[CDP] No message_id found in opened push payload.');
      return;
    }

    final sendContextId = data['send_context_id'] ?? "";
    final sendContext = data['send_context'] ?? "";

    await _implementation!.trackPushNotificationMetric(
      MetricEvent.opened,
      messageId,
      false,
      sendContext,
      sendContextId,
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
  }

  /// For testing: inject a mock/test HTTP client into the implementation
  @visibleForTesting
  static void setHttpClientForTest(dynamic client) {
    _implementation?.setHttpClient(client);
  }
}
