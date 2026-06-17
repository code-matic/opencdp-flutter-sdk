# Native push delivery failover — manual verification

Native Android/iOS push metric POSTs now try gateway hosts in the same order as Dart (`primary` → fallbacks), with short inline retries when all hosts fail.

## Prerequisites

- SDK initialized with `debug: true` (example app config screen).
- Valid API key and primary `cdpEndpoint`.
- Android: actionable notification or open/click receiver wired.
- iOS: app group configured; Notification Service Extension calls `OpenCdpPushExtensionHelper`.

## What gets persisted on init

Flutter saves to native storage:

- `opencdpsdk_base_url` — primary only (backward compatible)
- `opencdpsdk_base_urls` — full ordered list from `OpenCDPConfig.allBaseUrls`

## Android manual test

1. Run the example app and complete config + identify.
2. Trigger a notification **open** or **action click** (or use an actionable push).
3. In logcat, filter `OpenCDP`:
   - Expect `Push metric failed on <primary>` or `non-2xx … trying next host` when primary is bad.
   - Expect `Push metric sent via <host> (status=200)` on success.
4. Regression: clear app data, trigger open without SDK init — should still attempt `DEFAULT_GATEWAY_HOSTS` (`.com` → `.xyz` → `.io`).

## iOS manual test

1. Initialize SDK with app group; confirm extension can read prefs.
2. Send a push that runs the NSE `didReceiveNotificationExtensionRequest`.
3. In Console / extension logs, filter `OpenCDP SDK - Push Extension`:
   - Same host-by-host messages as Android.
4. Optional: write invalid primary to app group `opencdpsdk_base_url` only (no list) — should still try xyz/io fallbacks.

## Automated test

From repo root:

```bash
cd android && ./gradlew test
```

Runs `OpenCdpPushDeliveryClientTest` (host list parsing and resolution).

## Dart background path

`trackBackgroundPushNotificationMetric` uses `NativeBridge.resolveGatewayHostsFromNative()` when `isBackground: true`, so Dart-isolate background handlers also respect the stored host list.
