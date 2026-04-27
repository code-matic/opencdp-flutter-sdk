# Actionable Push Notifications (Manual Mode)

This guide is for apps using OpenCDP push payloads with `data.actions`.

For now, iOS action registration is **manual**:
- App teams maintain a fixed allowlist of `action_id` values.
- Those ids must be registered in native iOS/Android code.
- Campaign authors should only use ids on that allowlist.

## Prerequisites

- Base push tracking is already set up from the SDK README (`handleForegroundPushDelivery`, `handleBackgroundPushDelivery`, `handlePushNotificationOpen`).
- `firebase_core` + `firebase_messaging` configured.
- iOS App Group + Notification Service Extension configured.
- Android rendering can now be done by the SDK native bridge (`NotificationCompat` + `PendingIntent` + SDK receiver).

## 1) iOS: register `CDP_ACTIONS` category at launch

`action_id` in CDP must match `UNNotificationAction.identifier`.

```swift
import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerCDPActionCategory()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerCDPActionCategory() {
    let openAction = UNNotificationAction(
      identifier: "view_offer", // MUST match CDP action_id
      title: "View Offer",
      options: [.foreground]
    )
    let dismissAction = UNNotificationAction(
      identifier: "dismiss_offer", // MUST match CDP action_id
      title: "Dismiss",
      options: []
    )

    let category = UNNotificationCategory(
      identifier: "CDP_ACTIONS",
      actions: [openAction, dismissAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }
}
```

## 2) iOS: action tap handling

Forward action taps so Flutter can receive the tapped `action_id` and handle navigation/UX decisions.

```swift
import UserNotifications

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    if actionId != UNNotificationDefaultActionIdentifier &&
       actionId != UNNotificationDismissActionIdentifier {
      // Forward to Flutter side if needed.
      // Ensure Flutter eventually calls OpenCDPSDK.handlePushNotificationOpen(...)
      // with payload data that includes the tapped action id.
    }
    completionHandler()
  }
}
```

## 3) Android: render actions for background/terminated

When `actions` are present, Android push is data-focused. Use the SDK helper to render a native notification from payload `data`:

```dart
// lib/push_actions_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

class PushActionsService {
  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    await Firebase.initializeApp();

    // 1) Track delivery
    await OpenCDPSDK.handleBackgroundPushDelivery(message.data);

    // 2) Render native Android notification + actions (no-op on iOS)
    await OpenCDPSDK.showAndroidActionableNotification(
      message.data,
      channelName: 'CDP Notifications',
      channelDescription: 'Push notifications from CDP',
    );
  }
}
```

Wire it in `main.dart`:

```dart
FirebaseMessaging.onBackgroundMessage(PushActionsService.onBackgroundMessage);
```

What this helper does on Android:
- builds a `NotificationCompat.Builder` notification with payload `title` / `body`
- parses `data.actions` and adds up to 3 action buttons
- uses `PendingIntent` + SDK `BroadcastReceiver` to handle body/action taps
- forwards body/action taps via SDK receiver and opens the app with payload extras
- launches the app with extras (`opencdp_payload_json`, `opencdp_action_id`, `opencdp_link`)

## 4) Tap/open callback in Flutter

If you also show your own local notifications in Flutter, use this callback pattern for tap tracking:

```dart
Future<void> onLocalNotificationTap(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  final data = Map<String, dynamic>.from(jsonDecode(payload));
  final actionId = response.actionId;
  if (actionId != null && actionId.isNotEmpty) {
    data['action_id'] = actionId;
  }
  await OpenCDPSDK.handlePushNotificationOpen(data);
}
```

## 5) Smoke test payload

```json
{
  "delivery_message_id": "msg_123",
  "delivery_send_context": "campaign",
  "delivery_send_context_id": "cmp_123",
  "title": "Weekend offer",
  "body": "Choose an action",
  "android_channel_id": "marketing",
  "actions": "[{\"action_id\":\"view_offer\",\"label\":\"View\"},{\"action_id\":\"dismiss_offer\",\"label\":\"Dismiss\"}]"
}
```

Expected:
- `delivered` on receive
- `opened` on body tap
- action tap callback receives the expected `action_id`

## 6) QA Checklist (Release Readiness)

Use this checklist before shipping actionable push in a client app.

- Android permission: `POST_NOTIFICATIONS` granted on Android 13+.
- Device token registered after identify (`registerDeviceToken` called with fresh token).
- Background handler wired: `FirebaseMessaging.onBackgroundMessage(...)`.
- Payload has required keys: `delivery_message_id`, `delivery_send_context`, `delivery_send_context_id`.
- `actions` JSON contains valid rows with non-empty `action_id` and `label`.
- App opens correctly on body tap and on each action tap.
- Dashboard/events show:
  - `delivered` on receive
  - `opened` on body tap
  - action tap callback receives the expected `action_id`
- iOS `CDP_ACTIONS` category registered before receiving actionable push.
- iOS action identifiers exactly match campaign `action_id` values.
- iOS NSE is installed and App Group is identical across Runner + extension + SDK config.

## 7) Troubleshooting Quick Checks

- No buttons on Android:
  - Confirm notification was rendered via `OpenCDPSDK.showAndroidActionableNotification(...)`.
  - Confirm `data.actions` is valid JSON string array.
- Clicks not tracked:
  - Confirm API key and base URL are saved during SDK initialize.
  - Confirm `delivery_message_id` exists and is non-empty.
- Wrong action id tracked:
  - Confirm each button/intent uses the exact `action_id` from payload.

## Notes

- iOS button text comes from `UNNotificationAction(title:)` you register in app code.
- Identifier matching is strict: iOS/Android action id must equal CDP `action_id`.
- Adding a new `action_id` requires an app update in manual mode.
