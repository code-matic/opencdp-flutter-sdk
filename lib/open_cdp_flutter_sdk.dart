import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/initialization/sdk_initializer.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

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
  static void resetForTest() {
    _instance = null;
    _implementation = null;
    _screenTracker = null;
    _lifecycleTracker = null;
  }

  /// Initialize the SDK with configuration
  ///
  /// **REQUIRED**: This method must be called before using any SDK functionality.
  /// The SDK will not work properly if this method is not called.
  ///
  /// [httpClient] is for testing only and should not be used in production.
  static Future<void> initialize({
    required OpenCDPConfig config,
    @visibleForTesting CDPHttpClient? httpClient,
  }) async {
    try {
      if (_instance != null) {
        if (config.debug) {
          debugPrint('[CDP] SDK already initialized');
        }
        return;
      }

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
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error initializing SDK: $e');
      }
    }
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
  Future<void> update({
    required Map<String, dynamic> properties,
  }) async {
    if (_implementation == null) {
      debugPrint(
          '[CDP] ERROR: Cannot update user properties - SDK not initialized. Call OpenCDPSDK.initialize() first.');
      return;
    }
    await _implementation!.updateUserProperties(
      properties: properties,
    );
  }

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
    _implementation?.dispose();
    if (_lifecycleTracker != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleTracker!);
    }
  }

  /// For testing: inject a mock/test HTTP client into the implementation
  @visibleForTesting
  static void setHttpClientForTest(dynamic client) {
    _implementation?.setHttpClient(client);
  }
}
