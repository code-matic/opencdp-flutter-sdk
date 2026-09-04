# In-app messaging (OpenCDP)

Short reference for **OpenCDP** in-app messages via the Data Gateway.

**Recommended (3.3.0+):** enable auto-present, wrap with `OpenCDPInAppHost`, and
place `OpenCDPInAppInlineSlot` / `OpenCDPInAppInboxSlot` in your layout.
Advanced: listen to `messageStream` and render yourself.

## How it works

1. **`identify`** scopes deliveries to a person.
2. With **`enableInAppMessages: true`**, eligible messages are delivered on
   **`messageStream`** after you identify the user.
3. With **`enableInAppAutoPresent: true`** and an **`OpenCDPInAppHost`** ancestor,
   `modal` / `banner` show as overlays; slots show `inline` / `inbox_card`.
4. Slots and the host track impressions, clicks, and dismissals for you when
   you use the defaults (or call the provided callbacks from custom builders).

## 1. Initialize and identify

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'your-api-key',
    enableInAppMessages: true,
    enableInAppAutoPresent: true,
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
  builder: (context, child) => OpenCDPInAppHost(child: child!),
  // ...
);
```

Or set the logical screen yourself:

```dart
await OpenCDPSDK.instance.inApp?.setCurrentScreen('checkout');
```

## 2. Recommended: host + slots

```dart
MaterialApp(
  builder: (context, child) => OpenCDPInAppHost(child: child!),
  home: const HomePage(),
);

// In a screen layout:
Column(
  children: [
    OpenCDPInAppInlineSlot(slotId: 'home_above_balance'),
    // content…
  ],
);

// Inbox screen:
OpenCDPInAppInboxSlot();
```

Omit `modalBuilder` / `bannerBuilder` / slot `builder` to use
`OpenCDPInAppModalDialog`, `OpenCDPInAppBanner`, and `OpenCDPInAppInlineCard`.

**Do not** call Data Gateway interaction URLs with your own HTTP client — use
`CDPInAppManager` or `OpenCDPSDK.trackInApp*`.

### Order and multiple messages

- The backend returns messages in canonical order. The SDK **preserves that
  order** and only filters out deliveries it cannot show (expired, dismissed
  locally, persistence limits).
- The host shows **one modal at a time** (extras are queued). Banner replaces
  the previous overlay.
- Each delivery is emitted **at most once per app process** on `messageStream`.

## 3. Advanced: custom presentation

Set **`enableInAppAutoPresent: false`** and subscribe to **`messageStream`**:

```dart
OpenCDPSDK.instance.inApp?.messageStream.listen((msg) async {
  // Render modal / banner yourself…
  await OpenCDPSDK.instance.inApp?.trackImpression(msg);
  // On CTA: trackClick(message: msg, actionId: cta.id)
  // On close: trackDismiss(message: msg, reason: InAppDismissReason.userClose)
});
```

You may still mount `OpenCDPInAppHost` so slots receive inline / inbox while
you own modal/banner (or pass `forcePresent: true` to present overlays anyway).
Avoid double-presenting the same modal/banner with auto-present **and** a
custom listener.

## 4. Manual fetch (inbox / on-demand)

For screens you control entirely, call **`syncInAppMessages`** — it returns a
list and **does not** push to `messageStream`:

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

Set **`enableInAppMessages: false`** (default) if you only want this manual
path. Use `syncInAppMessages` and `trackInApp*` directly.

## 5. Useful manager APIs

```dart
await OpenCDPSDK.instance.inApp?.syncNow();           // refresh messages now (auto mode)
OpenCDPSDK.instance.inApp?.resetSession();          // clear local dismiss/impression cache
await OpenCDPSDK.instance.clearIdentity();          // logout
```

## Config reference

| Option | Default | Role |
|--------|---------|------|
| `enableInAppMessages` | `false` | Automatic delivery on `messageStream` |
| `enableInAppAutoPresent` | `false` | Host presents modal/banner overlays |
| `enableInAppRealtime` | `true` | Low-latency delivery when messages enabled |
| `inAppSyncLimit` | 10 | Max messages per fetch (1–50) |
| `autoTrackScreens` | `false` | Navigator-based screen → page rules |

## Example app

See `example/` — `OpenCDPInAppHost` in `main.dart`, `InAppLabScreen` in
`example/lib/in_app/in_app_lab_screen.dart`.

## Product docs

- [Flutter in-app messaging](https://docs.opencdp.io/integrations/flutter/features/in-app-messaging)
- [Mobile in-app hub](https://docs.opencdp.io/integrations/mobile/in-app-messaging)
