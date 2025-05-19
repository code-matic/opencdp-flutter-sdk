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
        sdk.trackLifecycleEvent(
          eventName: 'app_backgrounded',
          properties: {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        break;

      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          sdk.trackLifecycleEvent(
            eventName: 'app_foregrounded',
            properties: {
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          _wasBackgrounded = false;
        }
        sdk.trackLifecycleEvent(
          eventName: 'app_resumed',
          properties: {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        break;

      case AppLifecycleState.inactive:
        sdk.trackLifecycleEvent(
          eventName: 'app_inactive',
          properties: {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        break;

      case AppLifecycleState.detached:
        sdk.trackLifecycleEvent(
          eventName: 'app_detached',
          properties: {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        break;
    }

    if (debug) {
      debugPrint('[CDP] Tracked lifecycle event: ${state.name}');
    }
  }
}
