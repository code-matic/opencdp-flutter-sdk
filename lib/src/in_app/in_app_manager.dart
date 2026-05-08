import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

/// Reason a message was dismissed.
enum InAppDismissReason {
  userClose,
  userSwipe,
  ctaDismiss,
  expired,
  appBackgrounded,
  unknown;

  String get rawValue {
    switch (this) {
      case InAppDismissReason.userClose:
        return 'user_close';
      case InAppDismissReason.userSwipe:
        return 'user_swipe';
      case InAppDismissReason.ctaDismiss:
        return 'cta_dismiss';
      case InAppDismissReason.expired:
        return 'expired';
      case InAppDismissReason.appBackgrounded:
        return 'app_backgrounded';
      case InAppDismissReason.unknown:
        return 'unknown';
    }
  }
}

/// Listener invoked when a new in-app message is ready to be displayed by the
/// host app. The host is responsible for actually rendering it (modal, banner,
/// inline, inbox card, etc.) — the SDK only schedules and tracks it.
typedef InAppMessageListener = void Function(InAppMessage message);

/// Configuration for the in-app delivery manager.
class InAppManagerConfig {
  /// Whether the manager polls the sync endpoint automatically.
  final bool enabled;

  /// How frequently to poll for new in-app messages.
  final Duration pollInterval;

  /// Max messages requested per sync call (1..50).
  final int syncLimit;

  /// Optional override for the platform string sent to the backend.
  /// Defaults to `ios`, `android`, or `web`.
  final String? platformOverride;

  /// Optional override for the app version sent to the backend.
  /// If omitted, the manager falls back to package_info if available.
  final String? appVersionOverride;

  const InAppManagerConfig({
    this.enabled = false,
    this.pollInterval = const Duration(seconds: 30),
    this.syncLimit = 10,
    this.platformOverride,
    this.appVersionOverride,
  });
}

/// Internal record kept per delivery to enforce client-side persistence rules.
class _DeliveryState {
  int impressionsTotal = 0;
  DateTime? lastShownAt;
  bool dismissed = false;
}

/// Manages fetching, arbitration, display dispatch and tracking for in-app
/// messages. Designed to be initialized once per SDK instance.
class CDPInAppManager {
  final OpenCDPSDKImplementation _implementation;
  final OpenCDPConfig _config;
  final InAppManagerConfig managerConfig;

  final StreamController<InAppMessage> _messageStreamController =
      StreamController<InAppMessage>.broadcast();
  final List<InAppMessageListener> _listeners = [];
  final Map<String, _DeliveryState> _deliveryState = {};
  final Set<String> _dispatchedDeliveryIds = {};

  Timer? _pollTimer;
  String _currentScreen = 'unknown';
  bool _disposed = false;
  bool _syncInFlight = false;

  CDPInAppManager._(
    this._implementation,
    this._config,
    this.managerConfig,
  );

  factory CDPInAppManager.create({
    required OpenCDPSDKImplementation implementation,
    required OpenCDPConfig config,
    required InAppManagerConfig managerConfig,
  }) {
    final manager = CDPInAppManager._(
      implementation,
      config,
      managerConfig,
    );
    if (managerConfig.enabled) {
      manager._startPolling();
    }
    return manager;
  }

  /// Stream of in-app messages ready to be rendered.
  ///
  /// Each delivery is emitted at most once per app process. The host should
  /// render the message and then call [trackImpression] once it is on screen.
  Stream<InAppMessage> get messageStream => _messageStreamController.stream;

  /// Current logical screen name used for page-rule filtering on the backend
  /// and for impression/click tracking.
  String get currentScreen => _currentScreen;

  /// Add a callback that is invoked when a new in-app message is ready to be
  /// rendered. Listeners are kept in the order they are added.
  void addListener(InAppMessageListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(InAppMessageListener listener) {
    _listeners.remove(listener);
  }

  /// Update the current screen; the next poll uses this to filter messages.
  /// If [triggerSync] is true, an immediate sync is triggered.
  Future<void> setCurrentScreen(
    String screen, {
    bool triggerSync = true,
  }) async {
    if (screen.trim().isEmpty || _currentScreen == screen) {
      return;
    }
    _currentScreen = screen;
    if (managerConfig.enabled && triggerSync) {
      await syncNow();
    }
  }

  /// Reset locally tracked in-app state. Call when the active user changes
  /// (login/logout) so previously dispatched deliveries can be re-evaluated
  /// for the new identity.
  void resetSession() {
    _deliveryState.clear();
    _dispatchedDeliveryIds.clear();
    if (_config.debug) {
      debugPrint('[CDP] In-app local state reset');
    }
  }

  /// Force an immediate sync (no-op if a sync is already in-flight).
  Future<void> syncNow() async {
    if (_disposed || !managerConfig.enabled || _syncInFlight) return;
    _syncInFlight = true;
    try {
      final messages = await _implementation.syncInAppMessages(
        screen: _currentScreen,
        platform: managerConfig.platformOverride ?? _resolvePlatform(),
        appVersion: managerConfig.appVersionOverride,
        limit: managerConfig.syncLimit.clamp(1, 50),
      );

      final eligible = _arbitrate(messages);
      for (final message in eligible) {
        if (_dispatchedDeliveryIds.contains(message.deliveryId)) continue;
        _dispatchedDeliveryIds.add(message.deliveryId);
        _emit(message);
      }
    } catch (e) {
      if (_config.debug) {
        debugPrint('[CDP] In-app syncNow error: $e');
      }
    } finally {
      _syncInFlight = false;
    }
  }

  /// Mark a message as shown; sends an impression to the backend and updates
  /// local counters used by client-side persistence rules.
  Future<void> trackImpression(InAppMessage message) async {
    if (_disposed) return;
    final state = _deliveryState.putIfAbsent(
      message.deliveryId,
      _DeliveryState.new,
    );
    state.impressionsTotal += 1;
    state.lastShownAt = DateTime.now().toUtc();

    await _implementation.trackInAppImpression(
      deliveryId: message.deliveryId,
      screen: _currentScreen,
      platform: managerConfig.platformOverride ?? _resolvePlatform(),
      appVersion: managerConfig.appVersionOverride,
    );
  }

  /// Track a CTA click. The host should pass the CTA's id (or a custom value
  /// like `primary_cta`) so the backend can attribute the action.
  Future<void> trackClick({
    required InAppMessage message,
    required String actionId,
  }) async {
    if (_disposed) return;
    await _implementation.trackInAppClick(
      deliveryId: message.deliveryId,
      actionId: actionId,
      screen: _currentScreen,
    );
  }

  /// Track a dismiss event and lock the delivery from re-dispatch in this
  /// process.
  Future<void> trackDismiss({
    required InAppMessage message,
    InAppDismissReason reason = InAppDismissReason.unknown,
  }) async {
    if (_disposed) return;
    final state = _deliveryState.putIfAbsent(
      message.deliveryId,
      _DeliveryState.new,
    );
    state.dismissed = true;

    await _implementation.trackInAppDismiss(
      deliveryId: message.deliveryId,
      reason: reason.rawValue,
      screen: _currentScreen,
    );
  }

  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _messageStreamController.close();
    _listeners.clear();
    _deliveryState.clear();
    _dispatchedDeliveryIds.clear();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Schedule first sync soon, then on the configured interval.
    Future.delayed(const Duration(milliseconds: 500), syncNow);
    _pollTimer = Timer.periodic(managerConfig.pollInterval, (_) => syncNow());
  }

  void _emit(InAppMessage message) {
    if (_messageStreamController.isClosed) return;
    _messageStreamController.add(message);
    for (final listener in List<InAppMessageListener>.from(_listeners)) {
      try {
        listener(message);
      } catch (e) {
        if (_config.debug) {
          debugPrint('[CDP] In-app listener error: $e');
        }
      }
    }
  }

  /// Filter, sort and slice incoming messages using priority and persistence
  /// counters maintained locally. The backend already applies tenant/screen
  /// filtering — this is a final client-side guard so we don't re-show a
  /// dismissed or rate-limited message.
  List<InAppMessage> _arbitrate(List<InAppMessage> messages) {
    final now = DateTime.now().toUtc();
    final eligible = messages.where((message) {
      if (message.isExpired) return false;
      final state = _deliveryState[message.deliveryId];
      if (state == null) return true;
      if (state.dismissed) return false;
      final persistence = message.persistence;
      if (persistence != null) {
        final maxTotal = persistence.maxImpressionsTotal;
        if (maxTotal != null && state.impressionsTotal >= maxTotal) {
          return false;
        }
        final minInterval = persistence.minIntervalSeconds;
        final lastShownAt = state.lastShownAt;
        if (minInterval != null && lastShownAt != null) {
          final delta = now.difference(lastShownAt).inSeconds;
          if (delta < minInterval) return false;
        }
      }
      return true;
    }).toList();

    eligible.sort((a, b) => b.priority.compareTo(a.priority));
    return eligible;
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform may throw on unsupported runtime.
    }
    return 'unknown';
  }
}
