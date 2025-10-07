import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/utils/screen_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/utils/lifecycle_tracker.dart';
import 'package:open_cdp_flutter_sdk/src/integrations/customer_io_integration.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

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

    final MethodChannel _apiKeyChannel = MethodChannel('cdp/open-cdp');

    // The main initialization method for your SDK

    // ... your existing SDK initialization logic with the apiKey ...

    // Automatically store the key for push tracking if on iOS and app group is provided
    // kIsWeb is used to avoid running this on web platforms
    if (!kIsWeb && Platform.isIOS) {
      // if (config.iOSAppGroup == null) {
      //   debugPrint(
      //       "YourSdk Warning: 'iOSAppGroup' is not provided. Push notification delivery tracking will be disabled on iOS.");
      // }
      try {
        await _apiKeyChannel.invokeMethod('saveApiKey', {
          'apiKey': config.cdpApiKey,
          // 'appGroup': config.iOSAppGroup,
        });
      } on PlatformException catch (e) {
        debugPrint("Failed to save API key for push tracking: '${e.message}'.");
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
