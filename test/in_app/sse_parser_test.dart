import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/sse_parser.dart';

void main() {
  group('SseParser', () {
    test('emits a single event from a fully-buffered chunk', () {
      final parser = SseParser();
      final events = parser.addChunk('event: sync\ndata: {"x":1}\n\n');
      expect(events.length, 1);
      expect(events.first.event, 'sync');
      expect(events.first.data, '{"x":1}');
    });

    test('joins multiple data lines with \\n per spec', () {
      final parser = SseParser();
      final events = parser.addChunk('data: line1\ndata: line2\ndata: line3\n\n');
      expect(events.length, 1);
      expect(events.first.event, isNull);
      expect(events.first.data, 'line1\nline2\nline3');
    });

    test('handles event split across chunks', () {
      final parser = SseParser();
      expect(parser.addChunk('event: sy'), isEmpty);
      expect(parser.addChunk('nc\ndata: {"x"'), isEmpty);
      final last = parser.addChunk(':1}\n\n');
      expect(last.length, 1);
      expect(last.first.event, 'sync');
      expect(last.first.data, '{"x":1}');
    });

    test('ignores comment lines (heartbeats)', () {
      final parser = SseParser();
      expect(parser.addChunk(': hb\n: another\n'), isEmpty);
      final events = parser.addChunk('data: hello\n\n');
      expect(events.length, 1);
      expect(events.first.data, 'hello');
    });

    test('strips a single leading space from values', () {
      final parser = SseParser();
      final events = parser.addChunk('data:no-space\ndata: with-space\n\n');
      expect(events.length, 1);
      expect(events.first.data, 'no-space\nwith-space');
    });

    test('treats CRLF and standalone CR as line terminators', () {
      final parser = SseParser();
      // CRLF
      var events = parser.addChunk('event: a\r\ndata: 1\r\n\r\n');
      expect(events.length, 1);
      expect(events.first.event, 'a');
      expect(events.first.data, '1');
      // Standalone CR
      events = parser.addChunk('event: b\rdata: 2\r\r');
      expect(events.length, 1);
      expect(events.first.event, 'b');
      expect(events.first.data, '2');
    });

    test('captures id and exposes lastEventId', () {
      final parser = SseParser();
      final events = parser.addChunk('id: abc\ndata: hi\n\n');
      expect(events.length, 1);
      expect(events.first.id, 'abc');
      expect(parser.lastEventId, 'abc');
    });

    test('parses retry: as integer milliseconds', () {
      final parser = SseParser();
      final events = parser.addChunk('retry: 1500\ndata: hi\n\n');
      expect(events.length, 1);
      expect(events.first.retryMs, 1500);
    });

    test('ignores malformed retry values', () {
      final parser = SseParser();
      final events = parser.addChunk('retry: not-a-number\ndata: hi\n\n');
      expect(events.length, 1);
      expect(events.first.retryMs, isNull);
    });

    test('emits two events from one chunk', () {
      final parser = SseParser();
      final events = parser.addChunk('data: a\n\ndata: b\n\n');
      expect(events.length, 2);
      expect(events[0].data, 'a');
      expect(events[1].data, 'b');
    });

    test('treats line with no colon as a field with empty value', () {
      final parser = SseParser();
      // `data` alone (no colon, no value) should add an empty data line.
      final events = parser.addChunk('data\n\n');
      expect(events.length, 1);
      expect(events.first.data, '');
    });

    test('does not dispatch on stray empty lines with no preceding content', () {
      final parser = SseParser();
      final events = parser.addChunk('\n\n\n');
      expect(events, isEmpty);
    });
  });
}
