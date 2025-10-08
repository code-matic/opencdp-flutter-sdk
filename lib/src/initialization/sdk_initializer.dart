import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

    // Initialize screen tracker if auto tracking is enabled
    if (config.autoTrackScreens) {
      return CDPScreenTracker(
        sdk: sdk,
        debug: config.debug,
      );
    }

    // ✅ Save API key natively so background handlers can use it
    if (!kIsWeb) {
      try {
        if (Platform.isIOS) {
          // iOS requires an app group for Notification Service Extension
          if (config.iOSAppGroup != null) {
            await NativeBridge.saveApiKeyToNative(
              apiKey: config.cdpApiKey,
              appGroup: config.iOSAppGroup!,
            );
          } else {
            debugPrint(
              "[CDP] iOS App Group not provided. Background push tracking may fail.",
            );
          }
        } else if (Platform.isAndroid) {
          // ✅ For Android, just save using SharedPreferences
          await NativeBridge.saveApiKeyToNative(
            apiKey: config.cdpApiKey,
            appGroup: '', // not used but required by method signature
          );
        }
      } on PlatformException catch (e) {
        debugPrint("[CDP] Failed to save API key natively: ${e.message}");
      }
    }

    return null;
  }

  /// Initialize lifecycle tracker if enabled
  static CDPLifecycleTracker? initializeLifecycleTracker({
    required OpenCDPConfig config,
    required OpenCDPSDK sdk,
  }) {
    if (!config.trackApplicationLifecycleEvents) return null;

    final lifecycleTracker = CDPLifecycleTracker(
      sdk: sdk,
      debug: config.debug,
    );
    WidgetsBinding.instance.addObserver(lifecycleTracker);
    return lifecycleTracker;
  }
}
