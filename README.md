# Open CDP Flutter SDK

A Flutter SDK for integrating with the OpenCDP platform. Track user events, screen views, and device attributes with automatic lifecycle tracking and dual write to Customer.io 

## Features

- User identification and tracking
- Event tracking (custom, screen view, lifecycle)
- Device registration and push notification support
- Automatic screen tracking
- Application lifecycle tracking
- Customer.io integration
- Device attributes tracking

## Screen Tracking

The SDK provides automatic screen tracking through a `NavigatorObserver`. To enable automatic screen tracking:

1. Set `autoTrackScreens: true` in your SDK configuration:
```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    autoTrackScreens: true,
    // ... other config options
  ),
);
```

2. Add the screen tracker to your app's navigator observers:
```dart
MaterialApp(
  navigatorObservers: [
    OpenCDPSDK.instance.screenTracker!,
  ],
  // ... other app configuration
);
```

The screen tracker will automatically:
- Track all screen views in your app
- Store anonymous screen views until a user is identified
- Associate anonymous screen views with users once they are identified
- Include screen name, route, and timestamp in the tracking data

You can also manually track screen views using:
```dart
await OpenCDPSDK.instance.trackScreenView(
  title: 'Screen Name',
  properties: {'custom_property': 'value'},
);
```

---

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  open_cdp_flutter_sdk: ^1.0.0
```

---

## Quick Start

```dart
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the SDK - this must be done before using any SDK methods
  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: 'your-api-key',
      iOSAppGroup: 'your ios app group', // eg: group.com.yourcompany.yourapp
      debug: true,
      autoTrackScreens: true,
      trackApplicationLifecycleEvents: true,
      autoTrackDeviceAttributes: true,
      sendToCustomerIo: true,
      customerIo: CustomerIOConfig(
        apiKey: 'your-customer-io-api-key',
        inAppConfig: CustomerIOInAppConfig(
          siteId: 'your-site-id',
        ),
        migrationSiteId: 'your-migration-site-id',
        customerIoRegion: Region.us,
        autoTrackDeviceAttributes: true,
        pushConfig: CustomerIOPushConfig(
          pushConfigAndroid: CustomerIOPushConfigAndroid(
            pushClickBehavior: PushClickBehaviorAndroid.activityPreventRestart,
          ),
        ),
      ),
    ),
  );
  runApp(MyApp());
}
```

> **CRITICAL**: The SDK **MUST** be initialized before using any of its methods. If you don't initialize the SDK, all tracking operations will fail silently and you'll see error messages in the console. Make sure to await the `initialize()` call.

---

## Usage

### Identify Users
```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user123',
  properties: {'name': 'John Doe', 'email': 'john@example.com'},
);
```

### Track Events
```dart
await OpenCDPSDK.instance.track(
  eventName: 'purchase',
  properties: {'product_id': '123', 'price': 99.99},
);
```

### Track Screen Views
```dart
await OpenCDPSDK.instance.trackScreenView(
  title: 'Product Details',
  properties: {'product_id': '123'},
);
```

### Update User Properties
```dart
await OpenCDPSDK.instance.update(
  properties: {'last_purchase': DateTime.now().toIso8601String()},
);
```

### Register Device for Push Notifications
```dart
await OpenCDPSDK.instance.registerDeviceToken(
  fcmToken: 'firebase-token', // Android
  apnToken: 'apns-token',     // iOS
);
```

---

## Push Notification Tracking

If you want notification tracking enabled, follow these steps:

### OpenCDP SDK: Flutter Setup Guide

This guide provides step-by-step instructions to integrate the OpenCDP SDK into your Flutter app for real-time push notification tracking on iOS and Android.

#### 1. Installation

First, add the necessary packages to your project's pubspec.yaml file. You will need Firebase and the OpenCDP SDK.

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^latest
  firebase_messaging: ^latest

  # OpenCDP SDK - Make sure the name here matches your plugin's name
  open_cdp_flutter_sdk: ^latest
```

After adding the dependencies, run this command in your terminal to install them:

```bash
flutter pub get
```

#### 2. Add Push Tracking Code

This is all the Dart code required to track push notification events.

##### Step 2.1: Initialize Services

In your lib/main.dart file, initialize Firebase and the OpenCdpSdk. For iOS, you must provide the unique App Group ID that you will create in the iOS setup steps.

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the OpenCDP SDK
  await OpenCdpSdk.initialize(
    apiKey: "YOUR_API_KEY_HERE",
    iOSAppGroup: "group.com.yourcompany.yourapp" // The unique App Group you will create for iOS
  );
  
  // Set up push listeners after initialization
  await PushService.setupPushListeners();
  
  runApp(MyApp());
}

// ... your MyApp widget ...
```

##### Step 2.2: Set Up Push Handlers

Create a class and a top-level function to handle incoming notifications. This code uses the specific SDK methods for each event type.

```dart
// lib/main.dart or a new file like lib/push_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

// This handler must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // You must initialize Firebase here for the background isolate to work.
  await Firebase.initializeApp();
  
  // Let the SDK handle the background delivery event
  OpenCdpSdk.handleBackgroundPushDelivery(message.data);
}

class PushService {
  static Future<void> setupPushListeners() async {
    // 1. Set the background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Handles "delivered" events when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      OpenCdpSdk.handleForegroundPushDelivery(message.data);
    });

    // 3. Handles "opened" events if the app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        OpenCdpSdk.handlePushNotificationOpen(message.data);
      }
    });

    // 4. Handles "opened" events if the app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      OpenCdpSdk.handlePushNotificationOpen(message.data);
    });
  }
}
```

#### 3. Android Setup

No additional native configuration is required for Android. The Dart code you added is sufficient for full tracking.

#### 4. iOS Setup

iOS requires native configuration in Xcode to track notification delivery when your app is in the background.

##### Step 4.1: Add a Notification Service Extension

In your terminal, navigate to your project's ios folder and run pod install.

Open the Runner.xcworkspace file in Xcode.

From the Xcode menu, select File > New > Target....

Choose the Notification Service Extension template and click Next.

Enter a name (e.g., NotificationService) and click Finish. When prompted, click Do not Activate.

##### Step 4.2: Add an App Group

Select the main Runner target, then go to the Signing & Capabilities tab.

Click + Capability and add App Groups.

Click the + button and add a new group with a unique ID (e.g., group.com.yourcompany.yourapp). This ID must be the same one you used in your Dart code.

Select your NotificationService extension target and repeat the exact same steps, selecting the identical App Group ID.

##### Step 4.3: Add Code to the Extension

In the new NotificationService folder in Xcode, open NotificationService.swift and replace its contents with this code. This version allows the SDK to potentially modify the notification before it's displayed.

```swift
// In NotificationService/NotificationService.swift
import UserNotifications
import open_cdp_flutter_sdk // Import the SDK's native package

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // !!! IMPORTANT: Paste your App Group ID here !!!
        let appGroup = "group.com.yourcompany.yourapp"

        // Pass the request to the OpenCDP SDK Handler.
        // The SDK can now optionally modify the content before displaying.
        OpenCdpPushExtensionHelper.didReceiveNotificationExtensionRequest(
            request,
            appGroup: appGroup
        ) { modifiedContent in
            contentHandler(modifiedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called if the SDK's processing takes too long.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```


##### Step 4.4: Configure the Podfile

Open the Podfile in your ios directory.

Modify your Podfile to match the structure below. This is a robust configuration that correctly links all dependencies for both your main app and the extension.

```ruby
# In ios/Podfile

# ... (existing content like platform and project setup) ...

target 'Runner' do
  use_modular_headers! 
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Explicitly link the plugin to the main Runner target so GeneratedPluginRegistrant can find it.
  pod 'open_cdp_flutter_sdk', :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
end

target 'NotificationService' do
  # Inherit search paths allows the extension to find Flutter and other frameworks.
  inherit! :search_paths
  # This allows module imports without forcing dynamic frameworks.
  # Try to match with what is in the Runner target. 
  use_modular_headers! 
  # This explicitly links your SDK's native code to the extension.
  pod 'open_cdp_flutter_sdk', :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
end

post_install do |installer|
  # ... (existing content) ...
end
```

---

## Configuration Options

### OpenCDPConfig

| Option | Type | Description |
|--------|------|-------------|
| `cdpApiKey` | String | API key for Open CDP |
| `debug` | bool | Enable debug logging |
| `iOSAppGroup` | String | iOS app group identifier (e.g., group.com.yourcompany.yourapp) |
| `autoTrackScreens` | bool | Automatically track screen views |
| `trackApplicationLifecycleEvents` | bool | Track app lifecycle events |
| `autoTrackDeviceAttributes` | bool | Automatically track device attributes |
| `sendToCustomerIo` | bool | Enable Customer.io integration |
| `customerIo` | CustomerIOConfig | Customer.io configuration |

### CustomerIOConfig

| Option | Type | Description |
|--------|------|-------------|
| `apiKey` | String | Customer.io API key |
| `inAppConfig` | CustomerIOInAppConfig | In-app messaging configuration |
| `migrationSiteId` | String | Migration site ID |
| `customerIoRegion` | Region | Customer.io region (us/eu) |
| `autoTrackDeviceAttributes` | bool | Track device attributes in Customer.io |
| `pushConfig` | CustomerIOPushConfig | Push notification configuration |

---

## Event Types

- `custom`: Regular custom events
- `screenView`: Screen view events
- `lifecycle`: Application lifecycle events
- `device`: Device-related events

---

## Related Terms

analytics, CDP, tracking, Flutter, lifecycle, screen view

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) 

---

## License

[MIT](LICENSE)

---

## Where to Go Next

- [API Reference](https://github.com/code-matic/opencdp-flutter-sdk/blob/main/README.md)
- [Issue Tracker](https://github.com/code-matic/opencdp-flutter-sdk/issues)
- [Example App](example/README.md) 