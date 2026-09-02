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
}
