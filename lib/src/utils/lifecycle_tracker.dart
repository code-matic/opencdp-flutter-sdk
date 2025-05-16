import 'package:flutter/widgets.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// A widget observer that tracks application lifecycle events
class CDPLifecycleTracker extends WidgetsBindingObserver {
  /// The OpenCDPSDK instance used to send tracking events
  final OpenCDPSDK sdk;

  /// Whether to print debug information to the console
  final bool debug;

  /// Creates a new lifecycle tracker
  CDPLifecycleTracker({
    required this.sdk,
    this.debug = false,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (sdk.userId == null) return;

    final eventName = _getEventNameForState(state);
    if (eventName == null) return;

    sdk.track(
      identifier: sdk.userId!,
      eventName: eventName,
      properties: {
        'state': state.toString().split('.').last,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (debug) {
      debugPrint('[CDP] Tracked lifecycle event: $eventName');
    }
  }

  String? _getEventNameForState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return 'app_opened';
      case AppLifecycleState.paused:
        return 'app_closed';
      case AppLifecycleState.inactive:
        return 'app_inactive';
      case AppLifecycleState.detached:
        return 'app_detached';
      default:
        return null;
    }
  }
}
