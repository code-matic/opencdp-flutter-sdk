import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// A widget observer that tracks application lifecycle events
class CDPLifecycleTracker extends WidgetsBindingObserver {
  /// The OpenCDPSDK instance used to send tracking events
  final OpenCDPSDK sdk;

  /// Whether to print debug information to the console
  final bool debug;

  /// Whether the app was in background
  bool _wasBackgrounded = false;

  /// Creates a new lifecycle tracker
  CDPLifecycleTracker({
    required this.sdk,
    this.debug = false,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (sdk.userId == null) return;

    switch (state) {
      case AppLifecycleState.paused:
        _wasBackgrounded = true;
        _trackEvent('app_backgrounded');
        break;

      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          _trackEvent('app_foregrounded');
          _wasBackgrounded = false;
        }
        _trackEvent('app_resumed');
        break;

      case AppLifecycleState.inactive:
        _trackEvent('app_inactive');
        break;

      case AppLifecycleState.detached:
        _trackEvent('app_detached');
        break;
    }
  }

  void _trackEvent(String eventName) {
    sdk.track(
      identifier: sdk.userId!,
      eventName: eventName,
      properties: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (debug) {
      debugPrint('[CDP] Tracked lifecycle event: $eventName');
    }
  }
}
