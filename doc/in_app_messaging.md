# In-app messaging (OpenCDP)

Short reference for **Conviso / OpenCDP** in-app messages (Data Gateway). The SDK does not draw UI—you render `InAppMessage` in your app.

## Turn it on

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'your-api-key',
    enableInAppMessages: true,
    enableInAppRealtime: true, // SSE + catch-up sync (recommended)
    autoTrackScreens: true,    // feeds screen names into page rules
  ),
);
```

## Listen and track

Always use **`CDPInAppManager`** (or `OpenCDPSDK.instance.trackInAppImpression` / `trackInAppClick` / `trackInAppDismiss`). **Do not** call the Data Gateway interaction endpoints with your own HTTP client.

```dart
final sub = OpenCDPSDK.instance.inApp!.messageStream.listen((msg) async {
  // Show your modal/banner, then:
  await OpenCDPSDK.instance.inApp!.trackImpression(msg);
  // On CTA: trackClick(message: msg, actionId: cta.id)
  // On close: trackDismiss(message: msg, reason: InAppDismissReason.userClose)
});
```

## Manual sync (e.g. inbox screen)

```dart
final list = await OpenCDPSDK.instance.syncInAppMessages(
  screen: 'inbox',
  platform: 'ios', // or 'android' / 'web'
  limit: 20,
  tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
);
```

## Example app

See `example/lib/in_app/` in this repo (`InAppHost`, renderers).

## Product docs

- [Conviso: In-app messaging](https://docs.conviso.ai/docs/notifications/in-app-messaging)
- [Flutter integration](https://docs.conviso.ai/integrations/flutter/features/in-app-messaging)
