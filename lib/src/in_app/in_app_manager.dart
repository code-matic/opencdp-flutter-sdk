import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/sdk_implementation.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_realtime_client.dart';
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
  /// Whether the manager fetches in-app messages automatically.
  final bool enabled;

  /// Whether to open the realtime SSE stream. When false, the manager uses
  /// polling only.
  final bool enableRealtime;

  /// Polling cadence used when realtime is disabled or while the realtime
  /// stream is currently disconnected. While the realtime stream is healthy
  /// the polling timer is cancelled entirely — the stream's stale-connection
  /// watchdog (see [realtimeStaleTimeout]) is what protects against silent
  /// failures, not periodic polling.
  final Duration pollInterval;

  /// Maximum quiet period tolerated on a "connected" stream before it is
  /// torn down and reconnected. Controls how quickly we recover from a
  /// silently-broken stream.
  final Duration realtimeStaleTimeout;

  /// Upper bound on exponential-backoff reconnect attempts.
  final Duration realtimeMaxBackoff;

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
    this.enableRealtime = true,
    this.pollInterval = const Duration(seconds: 30),
    this.realtimeStaleTimeout = const Duration(seconds: 60),
    this.realtimeMaxBackoff = const Duration(seconds: 30),
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
  // Single-slot follow-up queue. While a sync is in-flight, additional
  // syncNow() calls collapse into this slot (keeping the most-urgent reason
  // — see [_pickHigherPriorityReason]). When the in-flight sync finishes the
  // run loop drains the slot and runs again. This replaces the old "drop the
  // call entirely" coalescing, which silently lost realtime_connected and
  // screen_change syncs whenever an earlier sync was still hanging on a slow
  // network.
  String? _pendingSyncReason;

  /// Active SSE client. Lifecycle is bound to the current identity — we
  /// rebuild it whenever [setActiveIdentity] is called with a new id so
  /// the stream auth and `person_id` query stay in sync with the user.
  CDPInAppRealtimeClient? _realtimeClient;
  // The lints `cancel_subscriptions` are suppressed here because the
  // subscriptions are cancelled in [_shutdownRealtime] (called from
  // [setActiveIdentity] and [dispose]), which the analyzer can't trace
  // through indirection.
  // ignore: cancel_subscriptions
  StreamSubscription<InAppRealtimeEvent>? _realtimeEventsSub;
  // ignore: cancel_subscriptions
  StreamSubscription<InAppRealtimeState>? _realtimeStateSub;
  String? _identity;
  bool _realtimeConnected = false;

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
      // The realtime client requires a known identity to subscribe; the SDK
      // will call [setActiveIdentity] once `identifyUser` resolves. We start
      // with the existing implementation user id so re-launches with a
      // persisted identity get realtime immediately.
      final initialIdentity = implementation.userId;
      if (initialIdentity != null && initialIdentity.isNotEmpty) {
        manager.setActiveIdentity(initialIdentity);
      }
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
      await syncNow(reason: 'screen_change');
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

  /// Inform the manager about the currently identified user. Triggers a
  /// realtime reconnect whenever the identity changes so the SSE stream's
  /// `person_id` query parameter stays in sync. Safe to call repeatedly
  /// with the same id (no-op).
  Future<void> setActiveIdentity(String? identity) async {
    if (_disposed || !managerConfig.enabled) return;
    final next = (identity == null || identity.trim().isEmpty) ? null : identity.trim();
    if (next == _identity) return;
    _identity = next;

    // Reset the periodic-only state so new pushes for this identity aren't
    // suppressed by leftover delivery ids from the previous user.
    resetSession();

    if (!managerConfig.enableRealtime || next == null) {
      // We're explicitly disabling realtime for this identity — this is the
      // one path where we want polling as a permanent fallback. The
      // _shutdownRealtime call itself does NOT schedule polling (that would
      // also fire during restarts and on cold start, before SSE has even
      // had a chance to connect — which is exactly the source of the
      // duplicate-poll requests we saw blowing the rate limit).
      await _shutdownRealtime();
      if (managerConfig.enabled && next != null) {
        _scheduleTimer(managerConfig.pollInterval);
      }
      return;
    }

    await _restartRealtime(next);
  }

  /// Force an immediate sync.
  ///
  /// [reason] is purely diagnostic — every call site tags itself (`initial`,
  /// `screen_change`, `realtime_event`, `realtime_connected`, `poll`,
  /// `manual`) so the SDK log makes it obvious which path delivered a given
  /// message. This was added because users couldn't tell whether a message
  /// arrived via SSE push or via reconnect catch-up.
  ///
  /// Concurrency model — queue of one:
  ///
  ///   * If no sync is currently in-flight, run immediately.
  ///   * If one is in-flight, record this call as the single pending follow-up
  ///     (keeping whichever reason is more urgent — see
  ///     [_pickHigherPriorityReason]) and return; the in-flight run drains
  ///     the pending slot when it finishes.
  ///
  /// This replaces the previous "drop the call" coalescing, which silently
  /// lost realtime_connected and screen_change syncs whenever an earlier
  /// sync was hanging on a slow network — leaving the SDK with a healthy
  /// SSE stream but no way to ever fetch the queued message.
  Future<void> syncNow({String reason = 'manual'}) async {
    if (_disposed || !managerConfig.enabled) {
      if (_config.debug) {
        debugPrint(
          '[CDP] In-app syncNow skipped reason=$reason disposed=$_disposed enabled=${managerConfig.enabled}',
        );
      }
      return;
    }

    if (_syncInFlight) {
      _pendingSyncReason =
          _pickHigherPriorityReason(_pendingSyncReason, reason);
      if (_config.debug) {
        debugPrint(
          '[CDP] In-app syncNow queued reason=$reason -> pending=$_pendingSyncReason',
        );
      }
      return;
    }

    // Mark in-flight before any await so concurrent callers fall into the
    // queue branch above instead of racing into a second sync loop.
    _syncInFlight = true;
    String currentReason = reason;
    try {
      while (true) {
        await _runSync(currentReason);
        if (_disposed) break;
        final next = _pendingSyncReason;
        if (next == null) break;
        _pendingSyncReason = null;
        currentReason = next;
        if (_config.debug) {
          debugPrint(
            '[CDP] In-app syncNow draining pending reason=$currentReason',
          );
        }
      }
    } finally {
      _syncInFlight = false;
    }
  }

  /// Run a single sync cycle. Never throws — failures are logged so the
  /// queue-drain loop in [syncNow] can continue to the next pending reason.
  Future<void> _runSync(String reason) async {
    final startedAt = DateTime.now();
    if (_config.debug) {
      debugPrint(
        '[CDP] In-app syncNow start reason=$reason screen=$_currentScreen',
      );
    }
    try {
      final messages = await _implementation.syncInAppMessages(
        screen: _currentScreen,
        platform: managerConfig.platformOverride ?? _resolvePlatform(),
        appVersion: managerConfig.appVersionOverride,
        limit: managerConfig.syncLimit.clamp(1, 50),
      );

      final eligible = _arbitrate(messages);
      var dispatched = 0;
      for (final message in eligible) {
        if (_dispatchedDeliveryIds.contains(message.deliveryId)) continue;
        _dispatchedDeliveryIds.add(message.deliveryId);
        _emit(message);
        dispatched += 1;
      }
      if (_config.debug) {
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint(
          '[CDP] In-app syncNow done reason=$reason fetched=${messages.length} eligible=${eligible.length} dispatched=$dispatched elapsedMs=$elapsedMs',
        );
      }
    } catch (e) {
      if (_config.debug) {
        debugPrint('[CDP] In-app syncNow error reason=$reason err=$e');
      }
    }
  }

  /// Pick whichever reason should win when collapsing multiple pending
  /// syncNow calls into a single follow-up. Higher number = more urgent.
  ///
  /// Rationale for the ordering:
  ///   * `realtime_event`     — the backend explicitly told us "fetch now"
  ///   * `realtime_connected` — catch-up after a (re)connect; equally urgent
  ///   * `manual`             — host app called syncNow() deliberately
  ///   * `initial`            — bootstrap; only fires once
  ///   * `screen_change`      — best-effort, can wait one cycle
  ///   * `poll`               — purely periodic, lowest priority
  ///
  /// Anything unrecognised gets a middling weight so unknown reasons don't
  /// accidentally beat realtime triggers.
  static String _pickHigherPriorityReason(String? current, String next) {
    if (current == null) return next;
    int weight(String r) {
      switch (r) {
        case 'realtime_event':
          return 100;
        case 'realtime_connected':
          return 90;
        case 'manual':
          return 80;
        case 'initial':
          return 70;
        case 'screen_change':
          return 60;
        case 'poll':
          return 10;
        default:
          return 50;
      }
    }
    return weight(next) > weight(current) ? next : current;
  }

  /// Test hook so unit tests can pin down the priority table without
  /// resorting to reflection.
  @visibleForTesting
  static String pickHigherPriorityReasonForTesting(
    String? current,
    String next,
  ) =>
      _pickHigherPriorityReason(current, next);

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
    unawaited(_shutdownRealtime());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Always do an immediate catch-up sync so a freshly-mounted manager
    // doesn't have to wait a full pollInterval (or for the first SSE event)
    // to render anything that's already queued for this person.
    Future.delayed(
      const Duration(milliseconds: 500),
      () => syncNow(reason: 'initial'),
    );
    // Periodic polling is only enabled when realtime is off. While the
    // realtime stream is healthy, we explicitly do not poll — silent stream
    // failure is detected by the per-connection stale-timeout watchdog and
    // the reconnect path runs its own catch-up sync.
    if (!managerConfig.enableRealtime) {
      _scheduleTimer(managerConfig.pollInterval);
    }
  }

  void _scheduleTimer(Duration interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      interval,
      (_) => syncNow(reason: 'poll'),
    );
  }

  void _cancelTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _restartRealtime(String identity) async {
    await _shutdownRealtime();
    if (_disposed) return;

    final client = CDPInAppRealtimeClient(
      httpClient: _implementation.cdpHttpClient,
      personId: identity,
      debug: _config.debug,
      maxBackoff: managerConfig.realtimeMaxBackoff,
      staleTimeout: managerConfig.realtimeStaleTimeout,
    );

    _realtimeEventsSub = client.events.listen((event) {
      if (event is InAppRealtimeSyncRequested) {
        // Server hint: "something changed for this person". The /sync call
        // is the source of truth; SSE never carries message content.
        unawaited(syncNow(reason: 'realtime_event'));
      }
    });

    _realtimeStateSub = client.stateChanges.listen(_handleRealtimeState);

    _realtimeClient = client;
    client.start();
  }

  Future<void> _shutdownRealtime() async {
    final client = _realtimeClient;
    final eventsSub = _realtimeEventsSub;
    final stateSub = _realtimeStateSub;
    _realtimeClient = null;
    _realtimeEventsSub = null;
    _realtimeStateSub = null;
    _realtimeConnected = false;
    // NOTE: do not start a polling timer here. This used to fall back to
    // polling unconditionally, but the same call path runs on cold start
    // (via _restartRealtime) and on every identity switch — which meant a
    // /sync request would fire 30s after launch even with realtime enabled,
    // doubling load on the rate limiter. Polling fallback is now only
    // scheduled by:
    //   * setActiveIdentity(null)/enableRealtime=false (long-term off path),
    //   * _handleRealtimeState (when we lose a previously-healthy stream).
    try {
      await eventsSub?.cancel();
    } catch (_) {/* best-effort */}
    try {
      await stateSub?.cancel();
    } catch (_) {/* best-effort */}
    if (client != null) {
      await client.dispose();
    }
  }

  void _handleRealtimeState(InAppRealtimeState state) {
    final wasConnected = _realtimeConnected;
    _realtimeConnected = state.connected;
    if (_config.debug) {
      debugPrint(
        '[CDP] In-app realtime state connected=${state.connected} reason=${state.reason.name} attempt=${state.retryAttempt} nextRetryMs=${state.nextRetryIn?.inMilliseconds ?? 0}',
      );
    }
    if (state.connected && !wasConnected) {
      // SSE just came up → no need for periodic polling; cancel the timer
      // to drive idle traffic to zero. Run an immediate catch-up sync so
      // anything that arrived during the disconnect window renders now,
      // not on the next push.
      _cancelTimer();
      unawaited(syncNow(reason: 'realtime_connected'));
    } else if (!state.connected && wasConnected) {
      // SSE just dropped → resume polling so deliveries still flow until
      // the realtime client successfully reconnects.
      if (managerConfig.enabled) {
        _scheduleTimer(managerConfig.pollInterval);
      }
    }
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
