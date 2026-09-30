import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

void main() {
  testWidgets('OpenCDPInAppModalDialog shows title and body', (tester) async {
    const message = InAppMessage(
      deliveryId: 'd1',
      messageId: 'm1',
      renderType: InAppRenderType.modal,
      priority: 10,
      title: 'Hello',
      body: 'World',
      ctas: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OpenCDPInAppModalDialog(message: message),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('OpenCDPInAppHost passes child through when auto-present off',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OpenCDPInAppHost(
          child: Text('child-ok'),
        ),
      ),
    );
    expect(find.text('child-ok'), findsOneWidget);
  });

  testWidgets(
    'OpenCDPInAppHost in MaterialApp.builder with navigatorKey resolves Navigator',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          builder: (context, child) => OpenCDPInAppHost(
            navigatorKey: navKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(navKey.currentContext, isNotNull);
      expect(navKey.currentState, isNotNull);
      expect(navKey.currentState!.overlay, isNotNull);

      // Same path the host uses for modal: showDialog via the keyed navigator.
      final dialog = showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(title: Text('via-key')),
      );
      await tester.pumpAndSettle();
      expect(find.text('via-key'), findsOneWidget);
      Navigator.of(navKey.currentContext!).pop();
      await dialog;
      await tester.pumpAndSettle();
    },
  );

  InAppMessage inboxMessage(String deliveryId) {
    return InAppMessage(
      deliveryId: deliveryId,
      messageId: 'm-$deliveryId',
      renderType: InAppRenderType.inboxCard,
      priority: 1,
      ctas: const [],
    );
  }

  Future<void> pumpHost(
    WidgetTester tester,
    Stream<InAppMessage> messages, {
    void Function(InAppMessage message)? onInlineMessage,
    void Function(InAppMessage message)? onInboxMessage,
  }) async {
    OpenCDPInAppHost.debugMessageStream = messages;
    addTearDown(() {
      OpenCDPInAppHost.debugMessageStream = null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OpenCDPInAppHost(
          onInlineMessage: onInlineMessage,
          onInboxMessage: onInboxMessage,
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets(
    'inbox card invokes onInlineMessage when onInboxMessage is null',
    (tester) async {
      final inline = <String>[];
      final controller = StreamController<InAppMessage>.broadcast();
      addTearDown(controller.close);
      await pumpHost(
        tester,
        controller.stream,
        onInlineMessage: (message) => inline.add(message.deliveryId),
      );

      controller.add(inboxMessage('inbox-1'));
      await tester.pump();

      expect(inline, ['inbox-1']);
    },
  );

  testWidgets(
    'inbox card prefers onInboxMessage when both callbacks are set',
    (tester) async {
      final inline = <String>[];
      final inbox = <String>[];
      final controller = StreamController<InAppMessage>.broadcast();
      addTearDown(controller.close);
      await pumpHost(
        tester,
        controller.stream,
        onInlineMessage: (message) => inline.add(message.deliveryId),
        onInboxMessage: (message) => inbox.add(message.deliveryId),
      );

      controller.add(inboxMessage('inbox-2'));
      await tester.pump();

      expect(inbox, ['inbox-2']);
      expect(inline, isEmpty);
    },
  );
}
