# Notification Service Extension template

Copy these files into your Flutter app's `ios/NotificationService/` folder and add a **Notification Service Extension** target in Xcode if you have not already.

1. Replace `YOUR_APP_GROUP` in `NotificationService.swift` and `NotificationService.entitlements` with the same value as `OpenCDPConfig.iOSAppGroup`.
2. Add the App Group capability to both **Runner** and **NotificationService** targets.
3. Add a Podfile target for `open_cdp_push_extension` (see SDK README).
4. The template uses `OpenCdpNotificationExtensionSession` for safe timeout handling — do not call `contentHandler` twice from `serviceExtensionTimeWillExpire`.

Backend must send `data.image_url` and set `aps.mutable-content: 1` for rich images on iOS.
