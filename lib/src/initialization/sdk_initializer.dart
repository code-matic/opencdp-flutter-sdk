import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
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
