# Changelog

## [3.2.2] - 2026-07-02

### Fixed

* **Android big-picture collapsed layout (API 31+)** — use `showBigPictureWhenCollapsed(true)` so `image_url` renders as a right-side thumbnail when collapsed; app icon stays via `setSmallIcon`. Pre-API 31 keeps left-side `setLargeIcon` fallback.
* **Android notification small icon** — `resolveSmallIcon` also checks host `ic_notification` drawable (common FCM manifest name).

## [3.2.1] - 2026-07-02

### Added

* **`OpenCDPSDK.handlePendingNotificationLaunch()`** — consumes SDK-rendered Android notification taps for routing via `onNotificationOpen` (native receiver already posts open/click metrics).
* **`OpenCdpNotificationExtensionSession`** — NSE template helper with safe expiration fallback and double-completion guard.

### Fixed

* **Android hybrid FCM deduplication** — implemented `cancel(0)`, active-notification title/body scan, and `delivery_message_id` notification tag in `OpenCdpNotificationRenderer`.
* **iOS NSE display latency** — `OpenCdpPushExtensionHelper` delivers enriched content before async delivery-metric POST.
* **iOS NSE expiration** — template uses `OpenCdpNotificationExtensionSession` so timeout delivers image-enriched content, not the pre-helper copy.
* **iOS background delivery metrics** — `appGroup` persisted at init for background-isolate credential reads when SDK instance is unavailable.
* **`agentDebugLog`** — gated behind `kDebugMode` so release builds do not POST debug telemetry on every background push.

## [3.2.0] - 2026-07-01

### Added

* **Turnkey push setup** — `OpenCDPSDK.configurePushBackground`, `OpenCDPSDK.firebaseBackgroundMessageHandler`, and `OpenCDPSDK.setupPushNotifications` wire FCM listeners, Android big-picture display, and delivery/open tracking in one call.
* **Android action button icons** — `actions[].icon` HTTPS URLs are downloaded and rendered on notification action buttons.

### Fixed

* **Android hybrid FCM deduplication** — `showAndroidActionableNotification` cancels FCM auto-posts (notification id `0`), matching title/body tray entries (including `EXTRA_BIG_TEXT`), and posts with a `delivery_message_id` notification tag so rich notifications replace plain FCM duplicates. Prefer data-only FCM for Android rich pushes.
* **Android rich push image** — restored `BigPictureStyle` layout: full image on expand (`bigLargeIcon(null)`), `showBigPictureWhenCollapsed(true)` for right-side collapsed thumbnail on API 31+, and `setLargeIcon` thumbnail fallback on API 24–30 only.
* **iOS rich push images** — `OpenCdpPushExtensionHelper` attaches `image_url` before delivery-metric guards so images appear even when tracking prerequisites are missing.
* **URL normalization** — `OpenCDPPushPayload.parseImageUrl` and iOS `parseImageUrl` prepend `https://` when the scheme is missing (matching Android).

## [3.1.3] - 2026-07-01

### Added

* **Push big-picture (`image_url`)**
  * Android `OpenCDPSDK.showAndroidActionableNotification(...)` now downloads `data.image_url` and renders a `BigPictureStyle` notification (text-only fallback when download fails).
  * iOS `OpenCdpPushExtensionHelper` attaches `image_url` as a `UNNotificationAttachment` in the Notification Service Extension (requires `aps.mutable-content: 1` from the backend).
  * **`OpenCDPPushPayload.parseImageUrl`** — helper for host apps that display pushes with their own notification plugin.

## [3.1.1] - 2026-05-18

### Changed

* **In-app messaging docs** — Updated setup and integration guides so they match how the SDK works today.

## [3.1.0] - 2026-05-18

### Added

* **In-app messaging (OpenCDP / Conviso)**
  * Deliver campaigns from the OpenCDP Data Gateway in your Flutter app. The SDK fetches and delivers messages; **you render the UI** (modal, banner, inline, inbox card) with your own widgets.
  * Turn on with `OpenCDPConfig(enableInAppMessages: true)`.
  * **`CDPInAppManager`** — subscribe to `messageStream` to show messages as they arrive; configurable sync limit and platform/app-version overrides.
  * **Manual sync** — `OpenCDPSDK.syncInAppMessages()` for inbox-style screens or on-demand refresh (optional `screen`, `platform`, `tzOffsetMinutes` for quiet hours).
  * **Interaction tracking** — `trackInAppImpression`, `trackInAppClick`, and `trackInAppDismiss` (or the matching methods on `CDPInAppManager`).
  * **Screen-aware delivery** — works with `autoTrackScreens` so page rules on the backend match the current route.
  * Setup guide: [Flutter in-app messaging](https://docs.conviso.ai/integrations/flutter/features/in-app-messaging). Example UI: `example/lib/in_app/` in this repository.

## [3.0.1] - 2026-05-08

### Fixed

* **Android build hotfix for actionable notifications**
  * Fixed a Kotlin compile issue in `OpenCdpNotificationRenderer` caused by `action` name shadowing in the banner action loop.
  * Updated intent action assignment to avoid lambda/property ambiguity (`setAction(...)`), restoring Android build compatibility.

## [3.0.0] - 2026-04-27

### Added

* **Android actionable push helper**
  * Added `OpenCDPSDK.showAndroidActionableNotification(...)` to display push notifications with action buttons from payload data.
  * Supports up to 3 actions from `data.actions` and handles body/action taps.

* **New setup guide for actionable push**
  * Added [Actionable Push Notifications (Manual Mode)](https://docs.conviso.ai/integrations/flutter/features/push-notifications#4-actionable-notifications-manual-mode) with copy-paste setup for Android and iOS manual mode.

### Improved

* **Push delivery endpoint now follows your SDK base URL**
  * Push tracking now respects `OpenCDPConfig.baseUrl` / `cdpEndpoint` (same behavior as other SDK events).
  * Works in foreground, background, and iOS notification extension flows.

## [2.0.0] - 2025-12-30

### Bug Fixes

* Fixed iOS build errors when using push notification tracking with notification service extensions
  * Resolved "Undefined symbol" linker errors that prevented iOS apps from building

### Breaking Changes

* **iOS Notification Service Extension setup required update**
  * If you're using push notification tracking with an iOS notification service extension, you must update your configuration:
  
  **Update your `Podfile`:**
  ```ruby
  target 'NotificationService' do
    use_frameworks!

    pod 'open_cdp_push_extension',
        :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
  end
  ```
  
  **Update your `NotificationService.swift`:**
  ```swift
  import UserNotifications
  import OpenCdpPushExtension  // Changed from: import open_cdp_flutter_sdk
  ```
  
  * After updating, run:
    ```bash
    cd ios
    rm -rf Pods Podfile.lock
    pod install
    ```
  
  * See the [README.md](README.md) for complete setup instructions

## [1.2.1] - 2025-11-13

* Updated `identify()` method to not accept email as identifier
  * Use the new `customerIoId` parameter if you need to use email as Id for Customer.io
* Added `customerIoId` parameter to `identify()` method for dual-write support
  * Use this when you need different identifiers for OpenCDP and Customer.io
* Added `throwErrorsBack` option to `OpenCDPConfig` for configurable error handling
  * Default (`false`): Errors are logged but don't throw exceptions - your app won't crash
  * Set to `true`: Catch and handle `CDPValidationException` and `CDPException` yourself
  * Choose based on your app's error handling strategy
* Enhanced input validation with helpful error messages

### Usage Examples

**Basic Usage (with non-email identifier):**
```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user_123',
  properties: {'name': 'John Doe'}
);
```

**Dual-Write Usage (with Customer.io email ID):**
```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user_123',           // Non-email ID for OpenCDP
  customerIoId: 'user@example.com', // Email ID for Customer.io
  properties: {'name': 'John Doe'}
);
```

## [1.2.0] - 2025-10-26

* Breaking Changes
  * Updated minimum Android SDK version to 24
  * Updated compileSdk to 36 for Android

* Updated dependencies
* Updated Kotlin version to 2.1.0
* Updated Android Gradle plugin to 8.9.1

## [1.1.0]
* Push notification tracking and deliverability improvements
  * Enhanced support for push notification handling in iOS app extensions using the specified app group
  * Ensures proper tracking of notifications received in app extensions
  * Android push notification tracking improvements
* Updated README with clearer instructions for push notification setup


## 1.0.5

* Breaking: Removed `OpenCDPSDK.update` (user properties update)
  * This method existed in 1.0.4 and earlier; it has now been removed from the public API
  * Migration: use `identify(identifier: ..., properties: {...})` to update traits
  * Related internal update method and example/test code have been removed/commented accordingly
* Updated CDP API endpoints
  * Base URL
  * No changes required in your integration—requests are routed automatically

## 1.0.4

* Updated the SDK to use the new OpenCDP API endpoint  
  * No changes required in your integration—your app will now automatically connect to the latest, more reliable OpenCDP service.
  * Ensures continued access to data and improved service stability.

## 1.0.3

* SDK now handles errors gracefully without crashing your app
  * No more try-catch blocks required in your code
  * Network failures and validation errors are logged but don't break functionality
  * App continues to work even when tracking operations fail
* Clear error messages when SDK is not properly initialized
  * Helps developers identify missing initialization calls
  * App remains stable even without proper SDK setup
* Better error messages and logging when debug mode is enabled

## 1.0.2

* Added offline request queue support
  * Failed requests are automatically queued
  * Queued requests are retried after successful requests
  * Queue persists between app restarts
* Removed unused meta package dependency
* Code cleanup and improvements

## 1.0.1

* Removed Customer.io push notification token registration from this SDK. For push notification setup with Customer.io, please follow their official documentation.

## 1.0.0

* Initial release
* User identification and tracking
* Event tracking with different types (custom, screen view, lifecycle)
* Device registration and push notification support
* Automatic screen tracking
* Application lifecycle tracking
* Customer.io integration
* Device attributes tracking
