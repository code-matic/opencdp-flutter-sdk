import 'package:flutter/foundation.dart';
import 'package:customer_io/customer_io.dart' as cio;
import 'package:customer_io/customer_io_config.dart' as cio_config;
import 'package:customer_io/customer_io_enums.dart' as cio_enums;
import 'package:open_cdp_flutter_sdk/src/models/config.dart';

/// Handles Customer.io integration
class CustomerIOIntegration {
  /// Initialize Customer.io with the given configuration
  static Future<void> initialize(OpenCDPConfig config) async {
    if (!config.sendToCustomerIo || config.customerIo == null) return;

    try {
      final inAppConfig = cio_config.InAppConfig(
        siteId: config.customerIo!.inAppConfig!.siteId,
      );
      final pushConfig = cio_config.PushConfig(
        android: _getPushConfigAndroid(
          config.customerIo?.pushConfig?.pushConfigAndroid.pushClickBehavior,
        ),
      );

      final cioConfig = cio_config.CustomerIOConfig(
        cdpApiKey: config.customerIo!.apiKey,
        inAppConfig: inAppConfig,
        migrationSiteId: config.customerIo!.migrationSiteId,
        region: config.customerIo!.customerIoRegion == Region.us
            ? cio_enums.Region.us
            : cio_enums.Region.eu,
        autoTrackDeviceAttributes: config.customerIo!.autoTrackDeviceAttributes,
        pushConfig: pushConfig,
      );

      await cio.CustomerIO.initialize(config: cioConfig);
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error initializing Customer.io: $e');
      }
    }
  }

  /// Get the Android push configuration based on the click behavior
  static cio_config.PushConfigAndroid? _getPushConfigAndroid(
    PushClickBehaviorAndroid? behavior,
  ) {
    if (behavior == null) return null;

    switch (behavior) {
      case PushClickBehaviorAndroid.activityPreventRestart:
        return cio_config.PushConfigAndroid(
          pushClickBehavior:
              cio_enums.PushClickBehaviorAndroid.activityPreventRestart,
        );
      case PushClickBehaviorAndroid.activityNoFlags:
        return cio_config.PushConfigAndroid(
          pushClickBehavior: cio_enums.PushClickBehaviorAndroid.activityNoFlags,
        );
      case PushClickBehaviorAndroid.resetTaskStack:
        return cio_config.PushConfigAndroid(
          pushClickBehavior: cio_enums.PushClickBehaviorAndroid.resetTaskStack,
        );
      default:
        return null;
    }
  }
}
