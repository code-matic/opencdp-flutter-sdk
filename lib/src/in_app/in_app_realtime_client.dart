import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/sse_parser.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

/// Reasons the client may transition between connection states. Surfaced
/// for observability so adopters can wire metrics or in-house logs.
enum InAppRealtimeStateReason {
  initial,
  connected,
  disconnected,
  retrying,
  paused,
  resumed,
  stopped,
}

class InAppRealtimeState {
  final bool connected;
  final InAppRealtimeStateReason reason;
  final int? retryAttempt;
  final Duration? nextRetryIn;

  const InAppRealtimeState({
    required this.connected,
    required this.reason,
    this.retryAttempt,
    this.nextRetryIn,
  });
}

/// Typed events emitted on the realtime stream. Today the only one the
/// server sends is [InAppRealtimeSyncRequested]; new event types should
/// be added as additional subclasses to keep the switch sites exhaustive.
abstract class InAppRealtimeEvent {
  const InAppRealtimeEvent();
}

/// Sent when the backend wants the SDK to refresh in-app messages by
/// hitting the existing `/sync` endpoint. Carries identifiers only — the
/// SDK never reads message content from the stream so eligibility logic
/// stays single-source on the backend.
class InAppRealtimeSyncRequested extends InAppRealtimeEvent {
  final String? deliveryId;
  final String? sourceType;
  final DateTime? ts;

  const InAppRealtimeSyncRequested({
    this.deliveryId,
    this.sourceType,
    this.ts,
  });
}

/// Long-lived Server-Sent Events client for the in-app messaging stream.
///
/// Design notes:
///   - Reuses the SDK's existing `http.Client` (and therefore its base URL
///     + Authorization header) via [CDPHttpClient.rawClient], so we never
///     duplicate auth or endpoint config.
///   - Exponential backoff with full jitter on reconnect, capped by
///     [maxBackoff]. The backoff resets after we successfully read a chunk
///     from the response body — a 200 alone isn't proof the proxy in front
///     of us actually established a stream.
///   - Foreground/background aware: pauses the stream on
///     `AppLifecycleState.paused`/`detached` so we don't keep a dead socket
///     hanging, and reconnects on `resumed`.
///   - Best-effort by design — failures here never throw upstream, the
///     `CDPInAppManager` falls back to the safety-net `/sync` poll.
class CDPInAppRealtimeClient with WidgetsBindingObserver {
  final CDPHttpClient _httpClient;
  final String _personId;
  final bool _debug;
  final Duration maxBackoff;
  final Duration initialBackoff;

  /// Maximum quiet period (no chunks — neither events nor heartbeats)
  /// tolerated on a connected stream before we assume it is silently
  /// broken and force a reconnect. The backend sends a heartbeat comment
  /// every ~20s so the default of 60s tolerates one missed beat before
  /// triggering recovery. Set to `Duration.zero` to disable the watchdog.
  final Duration staleTimeout;

  final Random _rng;

  /// Optional override used by tests so we don't have to wait for real
  /// backoff durations. Production code never sets this.
  @visibleForTesting
  final Future<void> Function(Duration)? sleeper;

  final StreamController<InAppRealtimeEvent> _eventController =
      StreamController<InAppRealtimeEvent>.broadcast();
  final StreamController<InAppRealtimeState> _stateController =
      StreamController<InAppRealtimeState>.broadcast();

  bool _started = false;
  bool _disposed = false;
  bool _paused = false;
  int _retryAttempt = 0;
  // Subscription owns the response body — cancelling it tears down the
  // underlying socket, which is all we need to disconnect.
  StreamSubscription<String>? _bodySubscription;
  Completer<void>? _connectionDone;
  String? _lastEventId;
  Timer? _staleWatchdog;
  DateTime? _lastChunkAt;
  // Stamped by whichever code path completes _connectionDone so the run
  // loop can log a meaningful disconnect cause (server_closed, stream_error,
  // watchdog_timeout, paused, etc.) rather than a generic "disconnected".
  String _lastDisconnectReason = 'unknown';
  // When the most recent connect attempt got a non-2xx, the run loop uses
  // this to override the normal exponential-backoff schedule:
  //   * 429 / 503 with Retry-After ⇒ honour it
  //   * 429 / 503 with no Retry-After ⇒ floor at [_throttleFloor]
  // Other 4xx (401/404) keep normal backoff because they are usually
  // misconfiguration and slamming retries won't fix them either way.
  Duration? _serverRequestedDelay;
  static const Duration _throttleFloor = Duration(seconds: 5);

  CDPInAppRealtimeClient({
    required CDPHttpClient httpClient,
    required String personId,
    bool debug = false,
    this.maxBackoff = const Duration(seconds: 30),
    this.initialBackoff = const Duration(seconds: 1),
    this.staleTimeout = const Duration(seconds: 60),
    Random? random,
    this.sleeper,
  })  : _httpClient = httpClient,
        _personId = personId,
        _debug = debug,
        _rng = random ?? Random();

  /// Stream of events received from the backend. Hot, broadcast.
  Stream<InAppRealtimeEvent> get events => _eventController.stream;

  /// Stream of connection state transitions. Useful for surfacing
  /// "realtime: connected" badges in adopter apps and for telemetry.
  Stream<InAppRealtimeState> get stateChanges => _stateController.stream;

  /// Whether [start] has been called and we have not yet been disposed.
  bool get isStarted => _started && !_disposed;

  /// Open the SSE connection (idempotent). Registers a lifecycle observer
  /// so we follow the app between foreground and background. Safe to call
  /// from any isolate that has a `WidgetsBinding`.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In headless/unit-test environments the binding may not exist; we
      // still want the connection loop to run.
    }
    _emitState(connected: false, reason: InAppRealtimeStateReason.initial);
    unawaited(_runLoop());
  }

  /// Close the connection and stop reconnect attempts. Idempotent.
  Future<void> stop() async {
    if (!_started || _disposed) return;
    _started = false;
    _emitState(connected: false, reason: InAppRealtimeStateReason.stopped);
    await _teardownActiveResponse();
  }

  /// Permanently shut down — stops reconnects and closes streams. After
  /// this the client cannot be restarted; callers should construct a new
  /// instance for a new identity.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {/* see start() */}
    await _teardownActiveResponse();
    await _eventController.close();
    await _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle integration
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _paused = true;
        _emitState(
          connected: false,
          reason: InAppRealtimeStateReason.paused,
        );
        // Tear down the existing response so the OS doesn't keep a half-open
        // socket; the loop will see _paused == true and idle until we resume.
        unawaited(_teardownActiveResponse());
        break;
      case AppLifecycleState.resumed:
        if (!_paused) return;
        _paused = false;
        _retryAttempt = 0;
        _emitState(
          connected: false,
          reason: InAppRealtimeStateReason.resumed,
        );
        if (_started && !_disposed) {
          unawaited(_runLoop());
        }
        break;
      case AppLifecycleState.inactive:
        // Transient state on iOS (incoming call, control center). Don't
        // tear the connection down — it'll usually resolve in milliseconds.
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Connection loop
  // ---------------------------------------------------------------------------

  Future<void> _runLoop() async {
    while (_started && !_disposed && !_paused) {
      String disconnectReason = 'unknown';
      try {
        await _openOnce();
        // _openOnce returns when the response body completes (server closed
        // the stream or the socket dropped). Treat that as "needs reconnect".
        if (!_started || _disposed || _paused) break;
        // The completer is completed by either the server closing the stream
        // (onDone), an error on the body subscription, or the watchdog
        // detecting silence. Each path sets `_lastDisconnectReason` so we
        // surface the actual cause here instead of a generic "disconnected".
        disconnectReason = _lastDisconnectReason;
        _lastDisconnectReason = 'unknown';
        _emitState(
          connected: false,
          reason: InAppRealtimeStateReason.disconnected,
        );
      } catch (e) {
        disconnectReason = 'exception:${e.runtimeType}';
        if (_debug) {
          debugPrint(
            '[CDP] In-app realtime error reason=$disconnectReason msg=$e',
          );
        }
        _emitState(
          connected: false,
          reason: InAppRealtimeStateReason.disconnected,
        );
      }

      if (!_started || _disposed || _paused) break;

      // Server-requested delay (Retry-After / 429-floor) wins over the
      // jitter schedule because it reflects the rate limiter's actual
      // recovery window. Clearing it after consumption ensures the next
      // failure goes back through normal backoff.
      Duration delay;
      final hint = _serverRequestedDelay;
      if (hint != null) {
        delay = hint > maxBackoff ? maxBackoff : hint;
        _serverRequestedDelay = null;
      } else {
        delay = _nextBackoff();
      }
      _emitState(
        connected: false,
        reason: InAppRealtimeStateReason.retrying,
        retryAttempt: _retryAttempt,
        nextRetryIn: delay,
      );
      _retryAttempt += 1;
      await (sleeper ?? Future.delayed)(delay);
    }
  }

  /// Parse an HTTP `Retry-After` value. Per RFC 7231 it can be either:
  ///   * an integer number of seconds (e.g. `Retry-After: 5`), or
  ///   * an HTTP-date (e.g. `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`).
  /// Returns null for missing or unparseable values so the caller can fall
  /// back to its own floor.
  static Duration? _parseRetryAfter(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      if (asInt <= 0) return Duration.zero;
      return Duration(seconds: asInt);
    }
    try {
      final when = HttpDate.parse(trimmed);
      final delta = when.difference(DateTime.now().toUtc());
      return delta.isNegative ? Duration.zero : delta;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openOnce() async {
    final uri = Uri.parse('${_httpClient.baseUrl}${CDPEndpoints.inAppStream}')
        .replace(queryParameters: {'person_id': _personId});

    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Authorization': _httpClient.apiKey,
    });
    if (_lastEventId != null && _lastEventId!.isNotEmpty) {
      // Standard SSE resume hint. The current backend ignores it (every
      // event is independent), but sending it keeps us forward-compatible
      // and zero-cost.
      request.headers['Last-Event-ID'] = _lastEventId!;
    }

    final response = await _httpClient.rawClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 4xx/5xx — drain and retry. We do not throw here because the loop
      // is responsible for backoff/recovery; throwing would just bubble
      // through unawaited futures and confuse Dart's error reporter.
      final status = response.statusCode;
      try {
        await response.stream.drain<void>();
      } catch (_) {/* ignore drain failures */}

      // Tell the run loop which path closed us so its disconnect log
      // attributes the cause correctly instead of falling back to "unknown".
      _lastDisconnectReason = 'non2xx_$status';

      // For 429/503 honour Retry-After (or fall back to a higher floor)
      // — full-jitter starting at 100ms here would just tighten the loop
      // around the limiter, which is what produced the `delayMs=196` we
      // saw bouncing off a 429 in production.
      if (status == 429 || status == 503) {
        final retryAfter = _parseRetryAfter(response.headers['retry-after']);
        if (retryAfter != null) {
          _serverRequestedDelay = retryAfter;
        } else {
          _serverRequestedDelay = _throttleFloor;
        }
      }

      if (_debug) {
        debugPrint(
          '[CDP] In-app realtime non-2xx status=$status nextDelayHint=${_serverRequestedDelay?.inMilliseconds ?? '-'}',
        );
      }
      return;
    }

    _connectionDone = Completer<void>();
    final parser = SseParser();
    bool sawFirstChunk = false;
    // Seed the watchdog before the first byte arrives so the server has
    // its full staleTimeout to send us anything (including the initial
    // `: connected` comment frame the gateway emits).
    _lastChunkAt = DateTime.now();
    _startStaleWatchdog();

    _bodySubscription = response.stream
        .transform(utf8.decoder)
        .listen(
      (chunk) {
        // Any chunk — event payload OR `: hb` heartbeat comment — counts
        // as proof of life. The watchdog only fires when the gap between
        // chunks exceeds [staleTimeout].
        _lastChunkAt = DateTime.now();
        if (!sawFirstChunk) {
          sawFirstChunk = true;
          _retryAttempt = 0;
          _emitState(
            connected: true,
            reason: InAppRealtimeStateReason.connected,
          );
        }
        for (final event in parser.addChunk(chunk)) {
          _lastEventId = parser.lastEventId;
          _dispatch(event);
        }
      },
      onError: (Object error, StackTrace st) {
        _lastDisconnectReason = 'stream_error:${error.runtimeType}';
        if (_debug) {
          debugPrint('[CDP] In-app realtime stream error: $error');
        }
        if (!(_connectionDone?.isCompleted ?? true)) {
          _connectionDone!.complete();
        }
      },
      onDone: () {
        // Server (or middleware) closed the response cleanly.
        _lastDisconnectReason = 'server_closed';
        if (!(_connectionDone?.isCompleted ?? true)) {
          _connectionDone!.complete();
        }
      },
      cancelOnError: true,
    );

    await _connectionDone!.future;
    _stopStaleWatchdog();
    await _bodySubscription?.cancel();
    _bodySubscription = null;
    _connectionDone = null;
  }

  /// Periodically (at staleTimeout / 3) check whether we have heard from
  /// the server within [staleTimeout]. If not, treat the stream as dead
  /// and force a reconnect — the OS may keep the TCP socket alive long
  /// after a middleware silently stops forwarding bytes.
  void _startStaleWatchdog() {
    _stopStaleWatchdog();
    if (staleTimeout <= Duration.zero) return;
    // Three checks per timeout window keeps detection latency bounded
    // without hammering the timer.
    final tickMs = (staleTimeout.inMilliseconds / 3).floor().clamp(250, 60000);
    _staleWatchdog = Timer.periodic(Duration(milliseconds: tickMs), (_) {
      final last = _lastChunkAt;
      if (last == null) return;
      if (DateTime.now().difference(last) < staleTimeout) return;
      if (_debug) {
        debugPrint(
          '[CDP] In-app realtime stream went silent for >${staleTimeout.inSeconds}s — forcing reconnect',
        );
      }
      _lastDisconnectReason = 'watchdog_timeout';
      // Completing the connection-done future drops us into the loop's
      // backoff path, which then re-establishes the stream and triggers
      // a catch-up sync via [_handleRealtimeState] in the manager.
      final completer = _connectionDone;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    });
  }

  void _stopStaleWatchdog() {
    _staleWatchdog?.cancel();
    _staleWatchdog = null;
    _lastChunkAt = null;
  }

  void _dispatch(ParsedSseEvent event) {
    if (_eventController.isClosed) return;
    final name = event.event ?? 'message';
    if (name == 'sync') {
      Map<String, dynamic> data = const {};
      if (event.data.isNotEmpty) {
        try {
          final decoded = jsonDecode(event.data);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          // Malformed payload — still surface a sync request because the
          // backend's intent was "refetch", and the manager's /sync call
          // is the source of truth either way.
        }
      }
      DateTime? ts;
      final tsRaw = data['ts'];
      if (tsRaw is String) {
        ts = DateTime.tryParse(tsRaw);
      }
      final deliveryId = data['delivery_id'] as String?;
      final sourceType = data['source_type'] as String?;
      _eventController.add(InAppRealtimeSyncRequested(
        deliveryId: deliveryId,
        sourceType: sourceType,
        ts: ts,
      ));
      return;
    }
    // Unknown event names are intentionally ignored — keeps us forward
    // compatible with future backend additions without an SDK update.
  }

  Future<void> _teardownActiveResponse() async {
    _stopStaleWatchdog();
    final completer = _connectionDone;
    if (completer != null && !completer.isCompleted) {
      // Preserve a previously-stamped reason (server_closed, watchdog_timeout,
      // stream_error). Only fall back to "client_teardown" when no other
      // path beat us to it — usually identity change, dispose, or background.
      if (_lastDisconnectReason == 'unknown') {
        _lastDisconnectReason = 'client_teardown';
      }
      completer.complete();
    }
    try {
      await _bodySubscription?.cancel();
    } catch (_) {/* best-effort */}
    _bodySubscription = null;
    _connectionDone = null;
  }

  /// Full-jitter exponential backoff: `delay = random(0, min(cap, base * 2^n))`.
  /// Full jitter is the AWS-recommended approach because it avoids the
  /// thundering-herd that bites equal-jitter and decorrelated-jitter
  /// strategies when many SDK clients reconnect after a backend restart.
  @visibleForTesting
  Duration computeBackoff(int attempt) => _computeBackoff(attempt);

  /// Test hook so we can assert Retry-After parsing without spinning up a
  /// real HTTP server. Mirrors the private `_parseRetryAfter` exactly.
  @visibleForTesting
  static Duration? parseRetryAfterForTesting(String? raw) =>
      _parseRetryAfter(raw);

  Duration _nextBackoff() => _computeBackoff(_retryAttempt);

  Duration _computeBackoff(int attempt) {
    final cappedExponent = attempt > 16 ? 16 : attempt;
    final exponential = initialBackoff.inMilliseconds * (1 << cappedExponent);
    final upperMs = exponential > maxBackoff.inMilliseconds
        ? maxBackoff.inMilliseconds
        : exponential;
    final jittered = _rng.nextInt(upperMs <= 0 ? 1 : upperMs);
    return Duration(milliseconds: jittered);
  }

  void _emitState({
    required bool connected,
    required InAppRealtimeStateReason reason,
    int? retryAttempt,
    Duration? nextRetryIn,
  }) {
    if (_stateController.isClosed) return;
    _stateController.add(InAppRealtimeState(
      connected: connected,
      reason: reason,
      retryAttempt: retryAttempt,
      nextRetryIn: nextRetryIn,
    ));
  }
}
