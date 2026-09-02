import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/open_cdp_in_app_slot_registry.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/open_cdp_in_app_slots.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

InAppMessage _msg({
  String id = 'd1',
  String title = 'Hello',
  InAppRenderType type = InAppRenderType.inline,
}) {
  return InAppMessage(
    deliveryId: id,
    messageId: 'm1',
    renderType: type,
    priority: 1,
    title: title,
    body: 'Body',
    ctas: const [
      InAppCta(id: 'cta1', label: 'Go', action: InAppCtaAction.dismiss),
    ],
  );
}

void main() {
  group('OpenCDPInAppSlotRegistry', () {
    test('matches every slot when targetSlotId is null', () {
      final registry = OpenCDPInAppSlotRegistry();
      registry.setInline(_msg());
      expect(registry.inlineForSlot(null), isNotNull);
      expect(registry.inlineForSlot('a'), isNotNull);
      expect(registry.inlineForSlot('b'), isNotNull);
    });

    test('matches only target slotId when set', () {
      final registry = OpenCDPInAppSlotRegistry();
      registry.setInline(_msg(), targetSlotId: 'home_above_wallet');
      expect(registry.inlineForSlot('home_above_wallet'), isNotNull);
      expect(registry.inlineForSlot('other'), isNull);
      expect(registry.inlineForSlot(null), isNull);
    });

    test('inbox dedupes by deliveryId', () {
      final registry = OpenCDPInAppSlotRegistry();
      registry.addInbox(_msg(id: 'x', type: InAppRenderType.inboxCard));
      registry.addInbox(_msg(id: 'x', type: InAppRenderType.inboxCard));
      expect(registry.inboxMessages, hasLength(1));
    });
  });

  group('OpenCDPInAppInlineSlot', () {
    testWidgets('renders default card when registry has message', (tester) async {
      final registry = OpenCDPInAppSlotRegistry();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenCDPInAppSlotScope(
            registry: registry,
            child: const Scaffold(
              body: OpenCDPInAppInlineSlot(),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsNothing);

      registry.setInline(_msg(title: 'Promo'));
      await tester.pump();
      expect(find.text('Promo'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);

      registry.clearInline();
      await tester.pump();
      expect(find.text('Promo'), findsNothing);
    });

    testWidgets('honors slotId filter', (tester) async {
      final registry = OpenCDPInAppSlotRegistry();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenCDPInAppSlotScope(
            registry: registry,
            child: const Scaffold(
              body: Column(
                children: [
                  OpenCDPInAppInlineSlot(slotId: 'a'),
                  OpenCDPInAppInlineSlot(slotId: 'b'),
                ],
              ),
            ),
          ),
        ),
      );

      registry.setInline(_msg(title: 'Only A'), targetSlotId: 'a');
      await tester.pump();
      expect(find.text('Only A'), findsOneWidget);
    });
  });
}
