import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_realtime_client.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

void main() {
  group('CDPInAppRealtimeClient.computeBackoff', () {
    Future<CDPInAppRealtimeClient> buildClient() async {
      // We never actually open a connection in these tests — we only call
      // the synchronous backoff helper. Build the client with a real
      // CDPHttpClient (constructor doesn't open sockets) and a deterministic
      // RNG so assertions are stable.
      final http = await CDPHttpClient.create(
        baseUrl: 'https://example.test',
        apiKey: 'unused',
      );
      return CDPInAppRealtimeClient(
        httpClient: http,
        personId: 'p_1',
        initialBackoff: const Duration(milliseconds: 1000),
        maxBackoff: const Duration(seconds: 30),
        random: Random(42),
      );
    }

    test('first attempt is bounded by 2 * initialBackoff', () async {
      final client = await buildClient();
      try {
        // attempt=0 ⇒ exponential = 1000ms ⇒ jitter in [0, 1000)
        final delay = client.computeBackoff(0);
        expect(delay.inMilliseconds, lessThan(1000));
        expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
      } finally {
        await client.dispose();
      }
    });

    test('caps at maxBackoff regardless of attempt count', () async {
      final client = await buildClient();
      try {
        // Very large attempt value should still be bounded by maxBackoff.
        for (final attempt in [10, 20, 50, 1000]) {
          final delay = client.computeBackoff(attempt);
          expect(
            delay.inMilliseconds,
            lessThan(30 * 1000),
            reason: 'attempt=$attempt produced ${delay.inMilliseconds}ms',
          );
        }
      } finally {
        await client.dispose();
      }
    });

    test('grows monotonically (in expectation) until cap', () async {
      final client = await buildClient();
      try {
        // We can't assert strict monotonicity per call (full jitter), but
        // the upper bound clearly grows: empirical max across many samples
        // for attempt=4 should exceed empirical max for attempt=0.
        int maxAt0 = 0;
        int maxAt4 = 0;
        for (int i = 0; i < 200; i++) {
          maxAt0 = max(maxAt0, client.computeBackoff(0).inMilliseconds);
          maxAt4 = max(maxAt4, client.computeBackoff(4).inMilliseconds);
        }
        expect(maxAt4, greaterThan(maxAt0));
      } finally {
        await client.dispose();
      }
    });
  });

  group('CDPInAppRealtimeClient.parseRetryAfterForTesting', () {
    test('parses integer seconds', () {
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting('5'),
        const Duration(seconds: 5),
      );
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting('  120  '),
        const Duration(seconds: 120),
      );
    });

    test('treats zero / negative integers as no-wait', () {
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting('0'),
        Duration.zero,
      );
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting('-3'),
        Duration.zero,
      );
    });

    test('parses HTTP-date and clamps past dates to zero', () {
      // Future date: returned duration should be > 0 and within a sane bound.
      final future = DateTime.now().toUtc().add(const Duration(seconds: 60));
      // RFC 1123 / IMF-fixdate, e.g. "Wed, 21 Oct 2026 07:28:00 GMT".
      final formatted = _formatHttpDate(future);
      final parsed = CDPInAppRealtimeClient.parseRetryAfterForTesting(formatted);
      expect(parsed, isNotNull);
      expect(parsed!.inSeconds, greaterThan(0));
      expect(parsed.inSeconds, lessThanOrEqualTo(60));

      // Past date: clamped to zero.
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 60));
      final pastParsed = CDPInAppRealtimeClient.parseRetryAfterForTesting(
        _formatHttpDate(past),
      );
      expect(pastParsed, Duration.zero);
    });

    test('returns null for unparseable input', () {
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting(null),
        isNull,
      );
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting(''),
        isNull,
      );
      expect(
        CDPInAppRealtimeClient.parseRetryAfterForTesting('not a date'),
        isNull,
      );
    });
  });
}

String _formatHttpDate(DateTime utc) {
  // Minimal IMF-fixdate formatter so the test is self-contained without
  // pulling in extra deps. HttpDate.parse accepts this format.
  const dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final dayName = dayNames[utc.weekday - 1];
  final month = monthNames[utc.month - 1];
  String two(int v) => v.toString().padLeft(2, '0');
  return '$dayName, ${two(utc.day)} $month ${utc.year} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} GMT';
}
