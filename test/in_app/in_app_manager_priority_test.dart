import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_manager.dart';

void main() {
  group('CDPInAppManager.pickHigherPriorityReasonForTesting', () {
    // The exhaustive list of known reasons in priority order (highest first).
    // If you add a new reason in the manager, add it here too — the test
    // verifies that ordering, so a bad weight will fail loudly.
    const orderHighToLow = <String>[
      'realtime_event',
      'realtime_connected',
      'manual',
      'initial',
      'screen_change',
      'poll',
    ];

    test('null current always loses to anything', () {
      for (final r in orderHighToLow) {
        expect(
          CDPInAppManager.pickHigherPriorityReasonForTesting(null, r),
          r,
          reason: 'null should be replaced by $r',
        );
      }
    });

    test('higher-priority reason wins regardless of order of arrival', () {
      // For every (high, low) pair, both call orders must end up returning
      // the high-priority one. This is the actual contract used in practice
      // — pending may already hold a low-priority reason when a high one
      // arrives, or vice versa.
      for (var i = 0; i < orderHighToLow.length; i++) {
        for (var j = i + 1; j < orderHighToLow.length; j++) {
          final high = orderHighToLow[i];
          final low = orderHighToLow[j];
          expect(
            CDPInAppManager.pickHigherPriorityReasonForTesting(high, low),
            high,
            reason: 'high($high) should beat low($low) when low arrives second',
          );
          expect(
            CDPInAppManager.pickHigherPriorityReasonForTesting(low, high),
            high,
            reason: 'high($high) should beat low($low) when high arrives second',
          );
        }
      }
    });

    test('equal priority keeps the existing pending reason (stable)', () {
      for (final r in orderHighToLow) {
        expect(
          CDPInAppManager.pickHigherPriorityReasonForTesting(r, r),
          r,
          reason: 'identical reasons should be a no-op',
        );
      }
    });

    test('unknown reason gets a middling weight (50)', () {
      // Below screen_change(60) — known mid-table reasons should beat unknown.
      expect(
        CDPInAppManager.pickHigherPriorityReasonForTesting('mystery', 'screen_change'),
        'screen_change',
      );
      // Above poll(10) — unknown should beat poll.
      expect(
        CDPInAppManager.pickHigherPriorityReasonForTesting('poll', 'mystery'),
        'mystery',
      );
      // Two unknowns of equal weight: stability rule applies, keep current.
      expect(
        CDPInAppManager.pickHigherPriorityReasonForTesting('alpha', 'beta'),
        'alpha',
      );
    });
  });
}
