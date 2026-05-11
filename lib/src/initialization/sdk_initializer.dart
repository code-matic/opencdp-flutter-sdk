import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/integrations/customer_io_integration.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';

/// Handles SDK initialization and setup
class SDKInitializer {
  /// Initialize the SDK with all required components
  static Future<CDPScreenTracker?> initialize({
    required OpenCDPConfig config,
    required OpenCDPSDK sdk,
    required OpenCDPSDKImplementation implementation,
  }) async {
    // Initialize Customer.io if configured
    await CustomerIOIntegration.initialize(config);

    // ✅ Save API key natively so background handlers can use it.
    // This is done early to ensure it's available for all app states.
    if (!kIsWeb) {
      try {
        // Save API key to native storage for background push notification handling
        await NativeBridge.saveApiKeyToNative(
          apiKey: config.cdpApiKey,
          appGroup: config.iOSAppGroup, // On Android, this argument is ignored
        );
        await NativeBridge.saveBaseUrlToNative(
          baseUrl: config.baseUrl,
          appGroup: config.iOSAppGroup,
        );

        // Warn if on iOS and the app group is missing
        if (Platform.isIOS && config.iOSAppGroup == null) {
          debugPrint(
            "[CDP] WARNING: iOS App Group not provided. Background push tracking may fail on iOS.",
          );
        }

        debugPrint(
            "[CDP] API key saved to native storage for background push tracking.");
      } catch (e) {
        debugPrint("[CDP] Failed to save API key natively: $e");
      }
    }

    // Initialize screen tracker if auto tracking is enabled
    if (config.autoTrackScreens) {
      return CDPScreenTracker(
        sdk: sdk,
        debug: config.debug,
      );
    }

    return null;
  }

  /// Initialize lifecycle tracker if enabled
  static CDPLifecycleTracker? initializeLifecycleTracker({
    required OpenCDPConfig config,
    required OpenCDPSDK sdk,
  }) {
    if (!config.trackApplicationLifecycleEvents) {
      return null;
    }

    final lifecycleTracker = CDPLifecycleTracker(
      sdk: sdk,
      debug: config.debug,
    );
    WidgetsBinding.instance.addObserver(lifecycleTracker);
    return lifecycleTracker;
  }

  /// Initialize the in-app message manager.
  ///
  /// Always returns an instance so the SDK can expose `OpenCDPSDK.instance.inApp`
  /// even when polling is disabled — host apps can still call sync/track methods
  /// manually. Polling only starts when [OpenCDPConfig.enableInAppMessages] is
  /// true.
  static CDPInAppManager initializeInAppManager({
    required OpenCDPConfig config,
    required OpenCDPSDKImplementation implementation,
  }) {
    return CDPInAppManager.create(
      implementation: implementation,
      config: config,
      managerConfig: InAppManagerConfig(
        enabled: config.enableInAppMessages,
        enableRealtime: config.enableInAppRealtime,
        pollInterval: config.inAppPollInterval,
        realtimeStaleTimeout: config.inAppRealtimeStaleTimeout,
        realtimeMaxBackoff: config.inAppRealtimeMaxBackoff,
        syncLimit: config.inAppSyncLimit,
        platformOverride: config.inAppPlatformOverride,
        appVersionOverride: config.inAppAppVersionOverride,
      ),
    );
  }
}
