import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_payload.dart';

/// Callback when the user opens a push notification or taps an action button.
typedef OpenCDPPushOpenCallback = void Function(
  Map<String, dynamic> data, {
  String? actionClicked,
});

/// Callback when a new FCM device token is available.
typedef OpenCDPPushTokenCallback = FutureOr<void> Function(String token);

/// Initializes Firebase in the background FCM isolate.
///
/// Host apps must set this via [OpenCDPSDK.configurePushBackground] before
/// registering [OpenCDPSDK.firebaseBackgroundMessageHandler].
typedef OpenCDPFirebaseInitializer = Future<void> Function();

/// Options for [OpenCDPSDK.setupPushNotifications].
class OpenCDPPushSetupOptions {
  const OpenCDPPushSetupOptions({
    this.channelName = 'CDP Notifications',
    this.channelDescription = 'Push notifications from CDP',
    this.requestPermission = true,
    this.onTokenRefreshed,
    this.onNotificationOpen,
  });

  final String channelName;
  final String channelDescription;
  final bool requestPermission;
  final OpenCDPPushTokenCallback? onTokenRefreshed;
  final OpenCDPPushOpenCallback? onNotificationOpen;
}

/// Whether the FCM message includes a top-level `notification` block (hybrid payload).
///
/// Hybrid payloads cause Android to auto-post a plain tray notification while the
/// app handler also posts a custom rich notification. Prefer **data-only** FCM for
/// Android rich pushes; the SDK cancels matching tray duplicates natively before post.
bool isHybridFcmMessage(RemoteMessage message) => message.notification != null;

/// Whether the payload should trigger a local Android notification display.
bool shouldDisplayAndroidPush(Map<String, dynamic> data) {
  final title = data['title']?.toString().trim();
  final body = data['body']?.toString().trim();
  return (title != null && title.isNotEmpty) ||
      (body != null && body.isNotEmpty) ||
      OpenCDPPushPayload.parseImageUrl(data) != null ||
      OpenCDPPushPayload.parseActions(data).isNotEmpty;
}
