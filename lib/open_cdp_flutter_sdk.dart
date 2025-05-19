import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/initialization/sdk_initializer.dart';

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
      throw StateError('SDK not initialized. Call initialize() first.');
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
  static Future<void> initialize({required OpenCDPConfig config}) async {
    if (_instance != null) {
      throw StateError('SDK already initialized');
    }

    _instance = OpenCDPSDK._();
    _implementation = await OpenCDPSDKImplementation.create(config: config);

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

  /// Private constructor
  OpenCDPSDK._();

  /// Identify a user with optional traits
  Future<void> identify({
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    await _implementation?.identifyUser(
      identifier: identifier,
      properties: properties,
    );
  }

  /// Track an event with optional properties
  Future<void> track({
    required String identifier,
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    await _implementation?.trackEvent(
      identifier: identifier,
      eventName: eventName,
      properties: properties,
    );
  }

  /// Update properties for a user
  Future<void> update({
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    await _implementation?.updateUserProperties(
      identifier: identifier,
      properties: properties,
    );
  }

  /// Track a screen view with optional properties
  Future<void> screen({
    required String identifier,
    required String title,
    Map<String, dynamic> properties = const {},
  }) async {
    await _implementation?.trackScreenView(
      identifier: identifier,
      title: title,
      properties: properties,
    );
  }

  /// Register a device token for push notifications
  Future<void> registerDeviceToken({
    required String identifier,
    String? fcmToken,
    String? apnToken,
  }) async {
    await _implementation?.registerDevice(
      identifier: identifier,
      fcmToken: fcmToken,
      apnToken: apnToken,
    );
  }

  /// Dispose the SDK instance
  void dispose() {
    _implementation?.dispose();
    if (_lifecycleTracker != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleTracker!);
    }
  }
}
