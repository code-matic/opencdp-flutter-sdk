import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_manager.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

/// These tests pin the canonical arbitration contract:
/// the server returns deliveries in `priority DESC, eligible_at ASC,
/// delivery_id ASC` order (see `cdp/docs/in-app-messaging-architecture.md`
/// §7.1) and the SDK MUST preserve that order. The SDK's only client-side
/// responsibility is dropping deliveries it can't show right now (expired,
/// locally dismissed, rate-limited by persistence rules). The test suite is
/// designed to catch any regression that re-introduces a client-side
/// `.sort(...)` over the server response.
void main() {
  InAppMessage buildMessage({
    required String id,
    required int priority,
    InAppPersistence? persistence,
    DateTime? expiresAt,
  }) {
    return InAppMessage(
      deliveryId: id,
      messageId: 'msg_$id',
      renderType: InAppRenderType.modal,
      priority: priority,
      ctas: const [],
      title: 'Title $id',
      expiresAt: expiresAt,
      persistence: persistence,
    );
  }

  group('CDPInAppManager arbitration — server order is canonical', () {
    test('preserves descending-priority server order', () {
      final messages = [
        buildMessage(id: 'a', priority: 90),
        buildMessage(id: 'b', priority: 50),
        buildMessage(id: 'c', priority: 10),
      ];

      final result = CDPInAppManager.filterEligibleForTesting(messages, const {});

      expect(result.map((m) => m.deliveryId).toList(), ['a', 'b', 'c']);
    });

    test('preserves ASCENDING-priority server order (catches accidental client re-sort)', () {
      // If anyone re-introduces `eligible.sort((a, b) => b.priority.compareTo(a.priority))`
      // this test fails immediately: the server's order [10, 50, 90] would be
      // flipped to [90, 50, 10]. We explicitly test the "wrong-looking" order
      // because the server may legitimately return it (e.g. when ties on
      // priority resolve via eligible_at or delivery_id and the older,
      // lower-priority message wins).
      final messages = [
        buildMessage(id: 'a', priority: 10),
        buildMessage(id: 'b', priority: 50),
        buildMessage(id: 'c', priority: 90),
      ];

      final result = CDPInAppManager.filterEligibleForTesting(messages, const {});

      expect(result.map((m) => m.deliveryId).toList(), ['a', 'b', 'c']);
    });

    test('preserves a mixed order verbatim', () {
      final messages = [
        buildMessage(id: 'a', priority: 50),
        buildMessage(id: 'b', priority: 90),
        buildMessage(id: 'c', priority: 10),
        buildMessage(id: 'd', priority: 50),
      ];

      final result = CDPInAppManager.filterEligibleForTesting(messages, const {});

      expect(result.map((m) => m.deliveryId).toList(), ['a', 'b', 'c', 'd']);
    });
  });

  group('CDPInAppManager arbitration — client-side filters', () {
    test('drops expired messages', () {
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      final messages = [
        buildMessage(id: 'a', priority: 50),
        buildMessage(id: 'b', priority: 90, expiresAt: past),
        buildMessage(id: 'c', priority: 10),
      ];

      final result = CDPInAppManager.filterEligibleForTesting(messages, const {});

      expect(result.map((m) => m.deliveryId).toList(), ['a', 'c']);
    });

    test('drops locally dismissed messages', () {
      final messages = [
        buildMessage(id: 'a', priority: 50),
        buildMessage(id: 'b', priority: 90),
        buildMessage(id: 'c', priority: 10),
      ];
      final state = {
        'b': const InAppArbitrationState(dismissed: true),
      };

      final result = CDPInAppManager.filterEligibleForTesting(messages, state);

      expect(result.map((m) => m.deliveryId).toList(), ['a', 'c']);
    });

    test('honors persistence.maxImpressionsTotal', () {
      final persistence = InAppPersistence.fromJson({
        'mode': 'persistent_until_dismissed',
        'max_impressions_total': 3,
      });
      final messages = [
        buildMessage(id: 'a', priority: 50, persistence: persistence),
        buildMessage(id: 'b', priority: 90, persistence: persistence),
      ];
      final state = {
        // Reached the cap → must be dropped.
        'a': const InAppArbitrationState(impressionsTotal: 3),
        // Below the cap → must stay.
        'b': const InAppArbitrationState(impressionsTotal: 2),
      };

      final result = CDPInAppManager.filterEligibleForTesting(messages, state);

      expect(result.map((m) => m.deliveryId).toList(), ['b']);
    });

    test('honors persistence.minIntervalSeconds against last shown', () {
      final persistence = InAppPersistence.fromJson({
        'mode': 'persistent_until_dismissed',
        'min_interval_seconds': 60,
      });
      final now = DateTime.utc(2026, 5, 12, 12, 0, 0);
      final messages = [
        // Shown 30s ago → must be dropped (still inside the 60s window).
        buildMessage(id: 'a', priority: 90, persistence: persistence),
        // Shown 90s ago → must stay (outside the window).
        buildMessage(id: 'b', priority: 50, persistence: persistence),
      ];
      final state = {
        'a': InAppArbitrationState(
          impressionsTotal: 1,
          lastShownAt: now.subtract(const Duration(seconds: 30)),
        ),
        'b': InAppArbitrationState(
          impressionsTotal: 1,
          lastShownAt: now.subtract(const Duration(seconds: 90)),
        ),
      };

      final result =
          CDPInAppManager.filterEligibleForTesting(messages, state, now: now);

      expect(result.map((m) => m.deliveryId).toList(), ['b']);
    });

    test('returns the empty list when every message is filtered out', () {
      final past = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      final messages = [
        buildMessage(id: 'a', priority: 50, expiresAt: past),
        buildMessage(id: 'b', priority: 90, expiresAt: past),
      ];

      final result = CDPInAppManager.filterEligibleForTesting(messages, const {});

      expect(result, isEmpty);
    });
  });
}
