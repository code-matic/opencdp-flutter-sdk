# Push notification v2 — cross-repo integration

This document coordinates three deliverables: **backend (FCM + APIs)**, **Open CDP Flutter SDK** (this repo; partially implemented here), and **host client app** (your Flutter product). Backend can ship first; the app needs SDK + native wiring for full parity.

## Pathway (order of work)

1. **Backend** — Extend FCM payload (`custom_data`, `actions`, delivery options, silent), fix deep-link Joi validation, accept `action_id` + `status: action_clicked` on `POST …/delivery/push`, optional workspace callbacks.
2. **Flutter SDK** (release) — Parse `custom_data` / `actions`, report `action_clicked` with `action_id`, document behavior (this package).
3. **Client app** — Upgrade SDK, route using parsed `custom_data`, register iOS `UNNotificationCategory` `CDP_ACTIONS`, build Android notification actions and wire taps into `OpenCDPSDK.handlePushNotificationOpen(..., action_clicked: '<action_id from native>')`.

---

## Backend repository

### FCM payload (`data` block)

- Add string key **`custom_data`**: JSON-serialized object of user-defined key-value pairs (Liquid-rendered values). Keeps a single namespace so keys never collide with CDP fields (`link`, `delivery_message_id`, etc.).
- Add string key **`actions`**: JSON-serialized array of up to 3 objects: `{ "action_id", "label", "link?", "icon?" }`. Do **not** rely on `android.notification.actions` in Firebase Admin Node types; both platforms read from `data`.
- Add string key **`image_url`**: HTTPS URL for a rich push image. Android: rendered by `showAndroidActionableNotification` via `BigPictureStyle`. iOS: attached in the Notification Service Extension when `aps.mutable-content: 1` is set.
- **Android rich push — data-only FCM**: send title, body, and `image_url` in the `data` block only. Do **not** include a top-level FCM `notification` block on Android when the app displays rich notifications via the SDK; hybrid payloads (`notification` + `data`) cause the OS to auto-post a plain notification **and** the SDK to post a rich one (duplicate tray entries). The SDK cancels FCM id `0` and matching tray posts before posting; **data-only is the reliable fix**.
- **Android notification tag**: when using hybrid payloads, set `android.notification.tag` to `delivery_message_id` so FCM auto-posts and SDK rich posts replace each other in the tray.
- Map **delivery options** to FCM: `android.priority`, `android.ttl` (ms from seconds), `android.notification.channelId`, `android.collapseKey`; APNS headers (`apns-priority`, `apns-expiration`, `apns-collapse-id`) and `aps` (`badge`, `sound`, `mutable-content`); set **`aps.category` = `CDP_ACTIONS`** when `actions` is non-empty; set **`aps.mutable-content` = `1`** when `image_url` or rich actions are present.
- **Silent push**: `silent: true` → data-only message, `content_available` / high priority as per spec; title/body optional only in that mode.

### Validation & types

- Extend `PushMessageContentProps` (and all six push Joi schemas + templates + test push) with optional: `custom_data`, `actions`, `ttl`, `priority`, `sound`, `badge`, `collapse_key`, `android_channel_id`, `silent`.
- **Bug fix**: `link` validation — use `Joi.string()` instead of `Joi.string().uri()` so `myapp://` deep links validate.

### Delivery endpoint (`POST /data-gateway/v1/delivery/push` or equivalent)

- Accept **`status: action_clicked`** distinct from `opened`.
- Accept optional **`action_id`** (string) on the request body; validate with Joi; pass through to analytics and outbound callbacks.

### Callbacks (if in scope)

- Workspace-level callback config, Cloud Tasks worker, `push.sent` enqueue after FCM success, enqueue on delivery events for subscribed event types — per product spec (try/catch; never fail primary flows).

### QA

- Unit tests for FCM mapping, Liquid on `custom_data`, delivery schema with `action_id`, callback enqueue.

---

## Flutter SDK repository (`open_cdp_flutter_sdk`)

### Done in this package (baseline v2 + v3.2 turnkey push)

- **`OpenCDPSDK.configurePushBackground` / `firebaseBackgroundMessageHandler` / `setupPushNotifications`** — turnkey FCM wiring with Android big-picture and delivery/open tracking (v3.2.0+).
- **`OpenCDPPushPayload.parseCustomData` / `parseActions` / `parseImageUrl`** — `lib/src/utils/push_notification_payload.dart` (exported).
- **`MetricEvent.actionClicked`** → API status **`clicked`** (with `props.action_id` when set).
- **Delivery POST** includes optional **`action_id`** in `props` when status is `clicked` (`PushNotificationTracker`).
- **`OpenCDPSDK.handlePendingNotificationLaunch()`** — Android SDK-rendered taps: native posts metrics; use for `onNotificationOpen` routing without double-counting.
- **`OpenCDPSDK.handlePushNotificationOpen(data, { String? action_clicked })`** — Value is the tapped button’s **`action_id`**. If that argument, `data['action_id']`, or `data['action_clicked']` (string) is non-empty → reports **`clicked`** + `props.action_id` on the wire; otherwise **opened**. Foreground delivery handler guards missing initialization.

- **Android actionable push helper** — `showAndroidActionableNotification` renders `image_url` with `BigPictureStyle` and `actions[].icon` on action buttons (v3.2.0+).
- **iOS NSE image attachment** — `OpenCdpPushExtensionHelper` downloads `image_url` when `mutable-content` is enabled (v3.1.3+).

### Optional follow-ups (same repo, later)

- Convenience API for local notification plugins (e.g. unified callback shape).

---

## Client app repository (host Flutter app)

### SDK upgrade

- Depend on the SDK version that exports **`OpenCDPPushPayload`** and **`handlePushNotificationOpen(..., action_clicked:)`**.

### Routing

- On notification open / cold start: `final custom = OpenCDPPushPayload.parseCustomData(message.data);` then navigate (e.g. GoRouter) using your keys (`screen`, `resource_id`, etc.).
- Default body tap: `OpenCDPSDK.handlePushNotificationOpen(message.data)` (no `action_clicked`).
- Action button tap: `OpenCDPSDK.handlePushNotificationOpen(message.data, action_clicked: '<action_id from native>')` **or** merge `action_id` / `action_clicked` into the map before calling.

### Android (SDK-rendered notifications)

- On cold/warm start from an SDK-rendered notification tap, call **`OpenCDPSDK.handlePendingNotificationLaunch()`** (wired automatically when using **`setupPushNotifications`**) to invoke **`onNotificationOpen`** for routing. Native code already posted open/click metrics — do not call **`handlePushNotificationOpen`** again for the same tap.

### Android

- **Notification channels**: `showAndroidActionableNotification` reads `data['android_channel_id']` as the channel **ID** and uses the `channelName` / `channelDescription` arguments as the human-readable label. The SDK calls `ensureChannel()` to create or update the channel. Set `com.google.firebase.messaging.default_notification_channel_id` in AndroidManifest to the same ID. You do not need a separate `flutter_local_notifications` channel for SDK-rendered pushes if the SDK owns display.
- Create **notification channels** whose IDs match what marketers set as `android_channel_id`.
- When displaying notifications locally, parse `OpenCDPPushPayload.parseActions(message.data)` and add up to three actions; on tap, resolve the correct `action_id` and call the SDK as above.
- For big-picture pushes, prefer `OpenCDPSDK.showAndroidActionableNotification(message.data)` (handles `image_url` natively) or `OpenCDPPushPayload.parseImageUrl(message.data)` if you use your own notification plugin.
- **Big-picture collapsed layout (Android 12+ / API 31+):** SDK uses `BigPictureStyle.showBigPictureWhenCollapsed(true)` so `image_url` renders as a **right-side thumbnail** when collapsed and a **large image at the bottom** when expanded. `setSmallIcon` keeps the app icon in the header on the left. Provide a monochrome notification drawable: `res/drawable/ic_stat_opencdp_notify` (preferred) or `ic_notification` (also recognized).
- **Big-picture collapsed layout (API 24–30):** Android does not support right-side collapsed thumbnails. SDK falls back to `setLargeIcon(thumbnail)` — image preview appears on the **left** next to the title. Expanded layout is unchanged (large image at bottom).

### iOS

- Register **`UNNotificationCategory`** identifier **`CDP_ACTIONS`** (and notification center delegate) so action buttons appear and you receive `actionIdentifier` / response; map that to **`action_clicked:`** (the button’s `action_id` string) for `handlePushNotificationOpen`.
- Rich / mutable content: keep existing Notification Service Extension pattern for **delivered** metrics and **`image_url`** attachments (`mutable-content: 1` required).

### Silent / data-only

- In `@pragma('vm:entry-point')` background handler, still call **`handleBackgroundPushDelivery(message.data)`** when `delivery_message_id` is present, even if there is no visible notification.

### Testing

- End-to-end: campaign with `custom_data` + actions → correct route + `action_clicked` vs `opened` in CDP analytics / callbacks.
- Big-picture manual E2E:
  - Android 12+ (API 31+): collapsed — app icon header left, `image_url` thumbnail right; expanded — large image at bottom.
  - Android API 24–30: collapsed — left-side image preview (platform limitation); expanded — large image at bottom.
  - Android background data-only push with `image_url` + actions → expanded big picture visible; failed download → text-only notification; delivery/open tracking unchanged.
  - iOS with NSE + `mutable-content: 1` → image attachment visible in notification.
  - Image URL must be HTTPS, publicly reachable, reasonable size (&lt; ~1MB), correct content-type.

---

## Contract summary

| Source | Key / behavior |
|--------|----------------|
| FCM `data` | `custom_data` (JSON string), `actions` (JSON string), `image_url` (HTTPS string), existing flat CDP keys |
| App → CDP | `status`: `delivered` \| `opened` \| `clicked` \| … ; optional `props.action_id` when `clicked` |
| iOS category | `CDP_ACTIONS` when server sends action buttons |

Questions: align `action_clicked` + `action_id` with your data-gateway schema before enabling strict validation on the server.

---

## Native port checklist (Android / iOS SDK parity)

Use this checklist when porting big-picture push from the Flutter SDK (v3.2.x) into **opencdp-android-sdk** and **opencdp-ios-sdk**. Flutter plugin sources are the canonical reference.

### Payload contract (all SDKs)

| Key | Type | Rules |
|-----|------|--------|
| `data.image_url` | string | HTTPS URL; scheme optional (SDK prepends `https://`); trim whitespace; empty → no image |
| `data.actions` | JSON string | Up to 3 items: `{ action_id, label, link?, icon? }` |
| `aps.mutable-content` | `1` | **iOS only** — required for NSE to attach `image_url` |

### Android (`OpenCdpNotificationRenderer` + `OpenCdpNotificationImage`)

- [ ] `parseImageUrl` / `normalizeImageUrl` — trim, reject blank, prepend `https://` when scheme missing
- [ ] Download `image_url` with retry (2 attempts, 500ms delay); 15s connect/read timeout
- [ ] Apply `NotificationCompat.BigPictureStyle` when download succeeds; text-only fallback when download fails
- [ ] **API 31+ (Android 12+):** `showBigPictureWhenCollapsed(true)` — right-side thumbnail when collapsed; full image when expanded
- [ ] **API 24–30:** `setLargeIcon(thumbnail)` fallback — left-side preview when collapsed
- [ ] `setSmallIcon` from `ic_stat_opencdp_notify` or `ic_notification` drawable, else app icon
- [ ] Action button icons from `actions[].icon` HTTPS URLs (download + `IconCompat.createWithBitmap`)
- [ ] `cancelHybridFcmDuplicates()` before posting — cancel id `0`, scan active notifications by title/body, tag by `delivery_message_id`
- [ ] Prefer **data-only FCM** (no top-level `notification` block) to avoid duplicate tray entries
- [ ] Entry point: `showActionableNotification(context, data, channelName, channelDescription)`
- [ ] Must not run image download on main thread (document for FCM background handler callers)

### iOS (`OpenCdpPushExtensionHelper` + `OpenCdpNotificationExtensionSession`)

- [ ] `parseImageUrl(from userInfo:)` / `normalizeImageUrl(_:)` — same rules as Android/Dart
- [ ] `attachImageIfPresent(userInfo:to:)` — download `image_url`, create `UNNotificationAttachment`
- [ ] **Delivery order:** attach image and call `completion(enrichedContent)` **before** async delivery metric POST
- [ ] Image attachment runs even when `delivery_message_id`, API key, or `person_id` are missing
- [ ] Delivery metric is fire-and-forget after content is delivered (display not blocked)
- [ ] `OpenCdpNotificationExtensionSession` — expiration fallback + double-completion guard for NSE targets
- [ ] Backend must set `aps.mutable-content: 1` when `image_url` is present

### Shared payload helpers

- [ ] `OpenCDPPushPayload.parseImageUrl(data)` exported on Android and iOS (same normalization as Flutter Dart helper)

### Manual E2E (all platforms)

- [ ] Android 12+ collapsed: app icon left, image thumbnail right; expanded: large image at bottom
- [ ] Android API 24–30: left-side image preview when collapsed
- [ ] Android: data-only FCM with `image_url` + actions; failed download → text-only notification
- [ ] iOS: NSE + `mutable-content: 1` → image visible in notification
- [ ] iOS: image shows even when delivery metric prerequisites are missing
