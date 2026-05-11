/// Streaming parser for Server-Sent Events frames.
///
/// SSE wire format ([spec](https://html.spec.whatwg.org/multipage/server-sent-events.html#parsing-an-event-stream)):
///
///   - The stream is a sequence of UTF-8 text lines terminated by `\n`,
///     `\r`, or `\r\n`.
///   - A line that starts with `:` is a comment (used as a heartbeat).
///   - Other lines have the form `field: value` (the `: ` after the colon
///     is optional; we trim a single leading space if present).
///   - An empty line ends the current event and "dispatches" it.
///
/// This parser is intentionally pure (no I/O, no timers) so it can be
/// trivially unit-tested. The realtime client feeds it raw chunks as they
/// arrive from the HTTP body and pulls completed events out via the
/// returned list.
library;

class ParsedSseEvent {
  /// Event name from the `event:` field, or null if not specified
  /// (clients should treat null as the default `message` event).
  final String? event;

  /// Concatenated `data:` field values, joined with `\n` per the spec.
  final String data;

  /// Optional `id:` field — used by the SDK as `Last-Event-ID` on reconnect.
  final String? id;

  /// Optional `retry:` field in milliseconds — server-suggested reconnect
  /// delay. The realtime client may honor or ignore this.
  final int? retryMs;

  const ParsedSseEvent({
    required this.data,
    this.event,
    this.id,
    this.retryMs,
  });
}

class SseParser {
  /// Buffer of bytes that haven't yet been split into a complete line.
  /// We keep this as a String because all SSE field values are UTF-8 text
  /// and the realtime client decodes chunks before feeding us.
  String _lineBuffer = '';

  /// In-progress event being assembled. Becomes a [ParsedSseEvent] when
  /// we see the dispatching empty line.
  final List<String> _dataLines = [];
  String? _eventName;
  String? _lastEventId;
  int? _retryMs;

  /// When the previous chunk ended on a lone CR, we flushed it as a
  /// terminator. If the next chunk starts with LF, that LF is the second
  /// half of a CRLF we already counted — swallow it so we don't emit a
  /// spurious empty line.
  bool _pendingLfSwallow = false;

  /// Most recent `id:` field — exposed so the realtime client can send it
  /// as `Last-Event-ID` on reconnect.
  String? get lastEventId => _lastEventId;

  /// Feed a chunk of decoded text and return any events that completed
  /// inside it. The returned list is empty when no event boundaries were
  /// crossed.
  List<ParsedSseEvent> addChunk(String chunk) {
    if (chunk.isEmpty) return const [];
    _lineBuffer += chunk;

    final events = <ParsedSseEvent>[];
    while (true) {
      final next = _extractNextLine();
      if (next == null) break;
      final dispatched = _processLine(next);
      if (dispatched != null) {
        events.add(dispatched);
      }
    }
    return events;
  }

  /// Pull the next complete line from `_lineBuffer`, removing it from the
  /// buffer. Returns null if no line terminator has arrived yet.
  ///
  /// Recognizes `\r\n`, `\n`, and standalone `\r` as line terminators,
  /// matching the SSE spec.
  String? _extractNextLine() {
    // If the previous chunk ended on a lone CR we flushed it as a
    // terminator. The current chunk might begin with the LF half of a
    // CRLF we already counted; consume that one byte before scanning.
    if (_pendingLfSwallow) {
      _pendingLfSwallow = false;
      if (_lineBuffer.isNotEmpty && _lineBuffer.codeUnitAt(0) == 0x0A) {
        _lineBuffer = _lineBuffer.substring(1);
      }
    }
    int idx = -1;
    int terminatorLength = 0;
    for (int i = 0; i < _lineBuffer.length; i++) {
      final ch = _lineBuffer.codeUnitAt(i);
      if (ch == 0x0A) {
        idx = i;
        terminatorLength = 1;
        break;
      }
      if (ch == 0x0D) {
        idx = i;
        terminatorLength = 1;
        if (i + 1 < _lineBuffer.length &&
            _lineBuffer.codeUnitAt(i + 1) == 0x0A) {
          terminatorLength = 2;
        } else if (i + 1 == _lineBuffer.length) {
          // Trailing CR — flush it eagerly so all-at-once inputs
          // dispatch correctly. The next chunk's leading LF (if any)
          // will be swallowed to avoid double counting.
          _pendingLfSwallow = true;
        }
        break;
      }
    }
    if (idx < 0) return null;
    final line = _lineBuffer.substring(0, idx);
    _lineBuffer = _lineBuffer.substring(idx + terminatorLength);
    return line;
  }

  /// Apply one already-extracted line. Returns a dispatched event if the
  /// line was the empty-line terminator that finishes the current event.
  ParsedSseEvent? _processLine(String line) {
    if (line.isEmpty) {
      if (_dataLines.isEmpty && _eventName == null && _retryMs == null) {
        // Empty line with no preceding content — nothing to dispatch.
        // (Some servers send extra blanks as noise.)
        return null;
      }
      final event = ParsedSseEvent(
        // Spec: data lines are concatenated with `\n`. If no `data:` was
        // sent (e.g. the server only sent `event:` and `id:`), surface an
        // empty string so callers don't have to null-check.
        data: _dataLines.join('\n'),
        event: _eventName,
        id: _lastEventId,
        retryMs: _retryMs,
      );
      _dataLines.clear();
      _eventName = null;
      _retryMs = null;
      // _lastEventId is sticky across events — it represents the last id
      // the server gave us, which the client uses for reconnect.
      return event;
    }

    // Comment line ⇒ ignore. Servers use these as heartbeats.
    if (line.startsWith(':')) {
      return null;
    }

    final colonIdx = line.indexOf(':');
    final String field;
    String value;
    if (colonIdx < 0) {
      // Per spec, a line with no colon is treated as a field with empty value.
      field = line;
      value = '';
    } else {
      field = line.substring(0, colonIdx);
      value = line.substring(colonIdx + 1);
      // Spec: if value starts with a single space, drop it.
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
    }

    switch (field) {
      case 'event':
        _eventName = value;
        break;
      case 'data':
        _dataLines.add(value);
        break;
      case 'id':
        // Spec: ignore ids that contain a NUL character.
        if (!value.contains('\u0000')) {
          _lastEventId = value;
        }
        break;
      case 'retry':
        final parsed = int.tryParse(value);
        if (parsed != null && parsed >= 0) {
          _retryMs = parsed;
        }
        break;
      default:
        // Unknown fields are ignored per spec.
        break;
    }
    return null;
  }
}
