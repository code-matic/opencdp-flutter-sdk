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

## Additional Guides

- [Actionable Push Notifications (Manual Mode)](https://docs.conviso.ai/integrations/flutter/features/push-notifications#4-actionable-notifications-manual-mode)

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

**Important:** The `identifier` parameter must NOT be an email address. Use a unique user ID instead.

#### Basic Usage
```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user123',  // Must NOT be an email address
  properties: {'name': 'John Doe', 'email': 'john@example.com'},
);
```

#### Dual-Write with Customer.io (using email as Customer.io ID)

If you need to use an email address as the identifier in Customer.io while maintaining a non-email identifier for CDP:

```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user123',           // Non-email ID for CDP API and native storage
  customerIoId: 'user@example.com', // Email ID for Customer.io integration
  properties: {'name': 'John Doe'},
);
```

**How it works:**
- `identifier` is used for CDP API calls and native storage (push notifications)
- `customerIoId` (optional) is used exclusively for Customer.io integration
- If `customerIoId` is not provided or empty, `identifier` is used for Customer.io as well

---

## Error Handling

The SDK provides two modes of error handling through the `throwErrorsBack` configuration option:

### Silent Error Handling (Default)

By default, errors are handled silently to prevent crashes:

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'your-api-key',
    debug: true,  // Errors logged only in debug mode
    throwErrorsBack: false,  // Default - silent error handling
  ),
);

// Errors are logged but don't throw exceptions
await OpenCDPSDK.instance.identify(
  identifier: 'user@example.com',  // Validation fails silently
  properties: {'name': 'John'},
);
```

### Strict Error Handling

Enable `throwErrorsBack` to catch and handle errors explicitly:

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'your-api-key',
    throwErrorsBack: true,  // Throw errors for explicit handling
  ),
);

// Now you must handle exceptions
try {
  await OpenCDPSDK.instance.identify(
    identifier: 'user@example.com',  // Throws CDPValidationException
    properties: {'name': 'John'},
  );
} on CDPValidationException catch (e) {
  // Handle validation errors (user input problems)
  print('Validation error: ${e.message}');
  // Show error to user, fix input, etc.
} on CDPException catch (e) {
  // Handle API errors (network/server problems)
  print('API error: ${e.message}, Status: ${e.statusCode}');
  // Retry, show error message, etc.
} catch (e) {
  // Handle other errors
  print('Unexpected error: $e');
}
```

**Exception Types:**
- `CDPValidationException` - Input validation failures (empty fields, invalid formats)
- `CDPException` - API/network errors (connection issues, server errors)

**Best Practices:**
- Use `throwErrorsBack: false` (default) for better UX - errors logged but don't crash
- Use `throwErrorsBack: true` for critical flows where you need to handle errors explicitly
- Always enable `debug: true` during development to see error logs

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

## In-App Messages

The SDK ships with a polling-based in-app delivery manager (`CDPInAppManager`)
that fetches messages from the OpenCDP backend, applies client-side
arbitration (priority, persistence, expiry), and notifies your app whenever a
new message is ready to be rendered. The SDK does **not** render any UI itself
— host apps own the look and feel using their existing design system.

### 1. Enable in-app polling

```dart
await OpenCDPSDK.initialize(
  config: OpenCDPConfig(
    cdpApiKey: 'YOUR_API_KEY_HERE',
    autoTrackScreens: true, // recommended: keeps the in-app screen filter in sync
    enableInAppMessages: true,
    inAppPollInterval: const Duration(seconds: 30),
    inAppSyncLimit: 10,
    // optional overrides:
    inAppPlatformOverride: null,    // defaults to 'ios' / 'android' / 'web'
    inAppAppVersionOverride: null,  // string sent to backend, default ''
  ),
);
```

When `enableInAppMessages: true`, the SDK starts polling shortly after
`initialize` completes. When `false` (the default), the manager is still
created so you can drive sync/tracking manually.

### 2. Listen for messages and render them

Subscribe to the manager's stream (or add a callback) and render the message
yourself. After the UI is on screen, call `trackImpression`. Hook your CTAs
up to `trackClick` and your dismiss UI to `trackDismiss`.

```dart
import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

class InAppMessageHost extends StatefulWidget {
  const InAppMessageHost({super.key, required this.child});
  final Widget child;

  @override
  State<InAppMessageHost> createState() => _InAppMessageHostState();
}

class _InAppMessageHostState extends State<InAppMessageHost> {
  StreamSubscription<InAppMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = OpenCDPSDK.instance.inApp?.messageStream.listen(_onMessage);
  }

  void _onMessage(InAppMessage message) async {
    if (!mounted) return;

    if (message.renderType == InAppRenderType.modal) {
      await OpenCDPSDK.instance.inApp?.trackImpression(message);
      final result = await showDialog<String>(
        context: context,
        builder: (_) => _InAppDialog(message: message),
      );
      if (result == null) {
        await OpenCDPSDK.instance.inApp?.trackDismiss(
          message: message,
          reason: InAppDismissReason.userClose,
        );
      } else {
        await OpenCDPSDK.instance.inApp?.trackClick(
          message: message,
          actionId: result,
        );
      }
    }
    // Handle other renderTypes (banner, inline, inboxCard) however you like.
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

### 3. Updating screen / session manually (optional)

If you don't use `autoTrackScreens`, call `setCurrentScreen` so backend page
rules can target the right surface, and `resetSession` whenever you want to
restart per-session counters (e.g. on login or after foregrounding):

```dart
OpenCDPSDK.instance.inApp?.setCurrentScreen('home');
OpenCDPSDK.instance.inApp?.resetSession();
```

You can also force a sync with `OpenCDPSDK.instance.inApp?.syncNow()`.

### 4. Manual mode without polling

Set `enableInAppMessages: false` (the default) and call the SDK directly when
you want messages — useful for "inbox" style screens:

```dart
final messages = await OpenCDPSDK.instance.syncInAppMessages(
  screen: 'inbox',
  sessionId: OpenCDPSDK.instance.inApp?.sessionId ?? 'no-session',
  platform: 'ios',
  appVersion: '1.0.0',
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

In your lib/main.dart file, initialize Firebase and the `OpenCDPSDK`. For iOS, you must provide the unique App Group ID that you will create in the iOS setup steps.

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the OpenCDP SDK
  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: "YOUR_API_KEY_HERE",
      iOSAppGroup: "group.com.yourcompany.yourapp", // App Group for iOS
      // Optional: cdpEndpoint: "https://your-tenant.data-gateway.cdp/...", // same base as identify/track
    ),
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
  OpenCDPSDK.handleBackgroundPushDelivery(message.data);
}

class PushService {
  static Future<void> setupPushListeners() async {
    // 1. Set the background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Handles "delivered" events when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      OpenCDPSDK.handleForegroundPushDelivery(message.data);
    });

    // 3. Handles "opened" events if the app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        OpenCDPSDK.handlePushNotificationOpen(message.data);
      }
    });

    // 4. Handles "opened" events if the app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      OpenCDPSDK.handlePushNotificationOpen(message.data);
    });
  }
}
```

#### 2.3 Notification action buttons (manual registration)

If you use **action buttons** in CDP (`data.actions` with `action_id` / `label`), use the dedicated guide:

**Android note:** For actionable pushes, the backend sends a data-focused FCM message (no top-level `notification` block). Preferred path is `OpenCDPSDK.showAndroidActionableNotification(...)` inside your background handler.

- [Actionable Push Notifications (Manual Mode)](https://docs.conviso.ai/integrations/flutter/features/push-notifications#4-actionable-notifications-manual-mode)

It includes:
- manual iOS category registration (`CDP_ACTIONS`) with copy/paste Swift
- SDK-native Android background/terminated rendering
- Flutter tap callback wiring for body and action taps
- payload smoke test + troubleshooting checklist

#### 3. Android Setup

No additional **native** configuration is required for **delivery and open tracking only**; the Dart handlers above are enough. If you add **action buttons** as in [2.3](#23-notification-action-buttons-manual-registration), see [Actionable Push Notifications (Manual Mode)](https://docs.conviso.ai/integrations/flutter/features/push-notifications#4-actionable-notifications-manual-mode) for SDK-native Android rendering and iOS manual registration.

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

In the new NotificationService folder in Xcode, open `NotificationService.swift` and replace its contents with the code below. Use the version matching your SDK.

---

###### For SDK v2.0.0 and later

```swift
// In NotificationService/NotificationService.swift
import UserNotifications
import OpenCdpPushExtension  // v2.0.0+ import

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

        OpenCdpPushExtensionHelper.didReceiveNotificationExtensionRequest(
            request,
            appGroup: appGroup
        ) { modifiedContent in
            contentHandler(modifiedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

---

###### For SDK v1.x (pre-2.0.0)

```swift
// In NotificationService/NotificationService.swift
import UserNotifications
import open_cdp_flutter_sdk  // v1.x import

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

        OpenCdpPushExtensionHelper.didReceiveNotificationExtensionRequest(
            request,
            appGroup: appGroup
        ) { modifiedContent in
            contentHandler(modifiedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```


##### Step 4.4: Configure the Podfile

Open the `Podfile` in your `ios` directory and configure it based on your SDK version.

---

###### For SDK v2.0.0 and later

The notification service extension uses a dedicated `open_cdp_push_extension` pod that doesn't depend on Flutter. This prevents linker errors in extension targets.

```ruby
# In ios/Podfile

# ... (existing content like platform and project setup) ...

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

target 'NotificationService' do
  use_frameworks!
  use_modular_headers!

  # Use the extension-only pod (no Flutter dependency)
  pod 'open_cdp_push_extension',
      :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

**In your `NotificationService.swift`, use:**
```swift
import OpenCdpPushExtension
```

---

###### For SDK v1.x (pre-2.0.0)

If you're using an older version of the SDK, configure the notification extension to use the main plugin pod:

```ruby
# In ios/Podfile

# ... (existing content like platform and project setup) ...

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

target 'NotificationService' do
  use_frameworks!
  use_modular_headers!

  pod 'open_cdp_flutter_sdk',
      :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

**In your `NotificationService.swift`, use:**
```swift
import open_cdp_flutter_sdk
```

---

After updating the Podfile, run:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

##### Step 4.5: Action Buttons End-to-End (copy/paste)

Moved to dedicated guide:

- [Actionable Push Notifications (Manual Mode)](https://docs.conviso.ai/integrations/flutter/features/push-notifications#4-actionable-notifications-manual-mode)

##### Common Issues

###### "Cycle Inside... building could produce unreliable results"

This build error can occur when using Xcode 15 or later. It's caused by a default configuration change in Xcode that affects projects with cross-platform dependencies like Flutter.

**To resolve this issue:**

1. Open your `.xcworkspace` file in Xcode (not the `.xcodeproj`).
2. Select your app target in the project navigator.
3. Navigate to the **Build Phases** tab.
4. Look for a phase named **"Embed Foundation Extensions"** or **"Embed App Extensions"**.
5. Drag this build phase and reposition it **above** the **"Run Script"** phase.
6. Rebuild your app.

The build should now complete successfully.

###### "Undefined symbol" linker errors after upgrading to v2.0.0

If you're upgrading from an earlier version and encounter linker errors related to undefined symbols, you need to update your notification service extension configuration.

**To resolve this issue:**

1. **Update your `Podfile`** — The notification service extension now uses a separate pod:
   ```ruby
   target 'NotificationService' do
     use_frameworks!
     use_modular_headers!

     pod 'open_cdp_push_extension',
         :path => '.symlinks/plugins/open_cdp_flutter_sdk/ios'
   end
   ```

2. **Update your `NotificationService.swift` import:**
   ```swift
   // Before (v1.x):
   import open_cdp_flutter_sdk
   
   // After (v2.0.0+):
   import OpenCdpPushExtension
   ```

3. **Clean and reinstall pods:**
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   ```

See the [CHANGELOG.md](CHANGELOG.md) for full details on breaking changes.

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