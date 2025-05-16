import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// A navigation observer that automatically tracks screen views in the CDP system.
///
/// This class extends [NavigatorObserver] to listen for navigation events
/// and track them as screen views in the CDP analytics system.
///
/// It handles both identified users and anonymous sessions, storing anonymous
/// screen views until a user is identified, at which point they are associated
/// with the user.
class CDPScreenTracker extends NavigatorObserver {
  /// The OpenCDPSDK instance used to send tracking events
  final OpenCDPSDK sdk;

  /// Whether to print debug information to the console
  final bool debug;

  /// Storage for screen views that occurred before user identification
  final List<Map<String, dynamic>> _anonymousScreenViews = [];

  /// Creates a new screen tracker.
  ///
  /// [sdk] is the OpenCDPSDK instance used to send tracking events.
  /// [debug] determines whether to print debug information to the console.
  CDPScreenTracker({
    required this.sdk,
    this.debug = false,
  });

  /// Called when a new route is pushed onto the navigator.
  ///
  /// Tracks the screen view for the new route.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackScreen(route);
  }

  /// Called when a route is replaced by another route.
  ///
  /// Tracks the screen view for the new route.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _trackScreen(newRoute);
    }
  }

  /// Called when a route is popped (user navigates back).
  ///
  /// Tracks the screen view for the previous route (now visible).
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _trackScreen(previousRoute);
    }
  }

  /// Tracks a screen view for the given route.
  ///
  /// If a user is identified, the screen view is immediately sent to CDP.
  /// Otherwise, it's stored for later association when a user is identified.
  void _trackScreen(Route<dynamic> route) {
    final settings = route.settings;
    final name = settings.name ?? route.toString();
    final screenData = {
      'screen': name,
      'route': name,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (sdk.userId != null) {
      // Track for identified user
      sdk.screen(
        sdk.userId!,
        name,
        properties: screenData,
      );

      if (debug) {
        debugPrint('[CDP] Tracked screen for user ${sdk.userId}: $name');
      }

      // If we have anonymous screen views, associate them with the user
      if (_anonymousScreenViews.isNotEmpty) {
        _associateAnonymousScreenViews();
      }
    } else {
      // Store anonymous screen view
      _anonymousScreenViews.add(screenData);
      if (debug) {
        debugPrint('[CDP] Stored anonymous screen view: $name');
      }
    }
  }

  /// Associates previously stored anonymous screen views with the now-identified user.
  ///
  /// This is called automatically when a user is identified and there are
  /// stored anonymous screen views.
  void _associateAnonymousScreenViews() {
    if (sdk.userId == null) return;

    for (final screenData in _anonymousScreenViews) {
      sdk.screen(
        sdk.userId!,
        screenData['screen'],
        properties: screenData,
      );

      if (debug) {
        debugPrint(
            '[CDP] Associated anonymous screen view with user ${sdk.userId}: ${screenData['screen']}');
      }
    }

    // Clear the anonymous screen views after associating them
    _anonymousScreenViews.clear();
  }
}
