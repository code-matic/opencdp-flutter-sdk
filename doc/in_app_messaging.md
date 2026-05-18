# In-app messaging (OpenCDP)

Short reference for **Conviso / OpenCDP** in-app messages via the Data Gateway. The SDK fetches deliveries and emits them to your app — **you render the UI** (`modal`, `banner`, `inline`, `inbox_card`).

## How it works

1. **`identify`** scopes deliveries to a person.
2. With **`enableInAppMessages: true`**, eligible messages are delivered on **`messageStream`** after you identify the user.
3. You render the UI and call the SDK to track impressions, clicks, and dismissals.

## 1. Initialize and identify

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'your-api-key',
    enableInAppMessages: true,
    autoTrackScreens: true,
    inAppSyncLimit: 10,
  ),
);

await OpenCDPSDK.instance.identify(
  identifier: 'user_123', // not an email — see README
  properties: {
    'first_name': 'Ada',
    'last_name': 'Lovelace',
    'email': 'ada@example.com',
  },
);
```

### Screen names for page rules

Either wire automatic screen tracking:

```dart
MaterialApp(
  navigatorObservers: [
    if (OpenCDPSDK.instance.screenTracker != null)
      OpenCDPSDK.instance.screenTracker!,
  ],
  // ...
);
```

Or set the logical screen yourself:

```dart
await OpenCDPSDK.instance.inApp?.setCurrentScreen('checkout');
```

## 2. Automatic delivery (recommended)

Subscribe to **`messageStream`**, render each `InAppMessage`, then track via the manager (screen and platform are filled in for you):

```dart
OpenCDPSDK.instance.inApp?.messageStream.listen((msg) async {
  // Render modal / banner / inline / inbox_card in your UI…
  await OpenCDPSDK.instance.inApp?.trackImpression(msg);
  // On CTA: trackClick(message: msg, actionId: cta.id)
  // On close: trackDismiss(message: msg, reason: InAppDismissReason.userClose)
});
```

**Do not** call Data Gateway interaction URLs with your own HTTP client — use `CDPInAppManager` or `OpenCDPSDK.trackInApp*`.

### Order and multiple messages

- The backend returns messages in canonical order. The SDK **preserves that order** and only filters out deliveries it cannot show (expired, dismissed locally, persistence limits).
- Showing **one modal at a time** (or similar slot rules) is your app's responsibility — walk the list from the first item.

Each delivery is emitted **at most once per app process** on `messageStream`.

## 3. Manual fetch (inbox / on-demand)

For screens you control entirely, call **`syncInAppMessages`** — it returns a list and **does not** push to `messageStream`:

```dart
final list = await OpenCDPSDK.instance.syncInAppMessages(
  screen: 'inbox',
  platform: 'ios', // or 'android' / 'web'
  limit: 20,
  tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
);

for (final msg in list) {
  // render…
  await OpenCDPSDK.instance.trackInAppImpression(
    deliveryId: msg.deliveryId,
    screen: 'inbox',
    platform: 'ios',
  );
}
```

Set **`enableInAppMessages: false`** (default) if you only want this manual path. Use `syncInAppMessages` and `trackInApp*` directly.

## 4. Useful manager APIs

```dart
await OpenCDPSDK.instance.inApp?.syncNow();           // refresh messages now (auto mode)
OpenCDPSDK.instance.inApp?.resetSession();          // clear local dismiss/impression cache
await OpenCDPSDK.instance.clearIdentity();          // logout
```

## Config reference

| Option | Default | Role |
|--------|---------|------|
| `enableInAppMessages` | `false` | Automatic delivery on `messageStream` |
| `inAppSyncLimit` | 10 | Max messages per fetch (1–50) |
| `autoTrackScreens` | `false` | Navigator-based screen → page rules |

## Example app

See `example/lib/in_app/` (`InAppHost`, renderers) and `example/README.md`.

## Product docs

- [Conviso: In-app messaging](https://docs.conviso.ai/docs/notifications/in-app-messaging)
- [Flutter integration](https://docs.conviso.ai/integrations/flutter/features/in-app-messaging)
