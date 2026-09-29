import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/open_cdp_in_app_widgets.dart';

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
}
