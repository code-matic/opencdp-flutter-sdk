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
  WidgetsFlutterBinding.ensureInitialized();
  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: 'your-api-key',
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

## Customer.io Push Notification Setup

If you're using Customer.io for push notifications, you need to set up your app to handle push notifications properly. Please refer to the [Customer.io Push Notification Setup Guide](https://docs.customer.io/sdk/flutter/push-notifications/push-setup/) for detailed instructions on:

- Setting up push notifications for Android
- Setting up push notifications for iOS
- Configuring notification icons and sounds
- Handling notification permissions
- Testing your implementation

---

## Configuration Options

### OpenCDPConfig

| Option | Type | Description |
|--------|------|-------------|
| `cdpApiKey` | String | API key for Open CDP |
| `debug` | bool | Enable debug logging |
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

MIT License

---

## Where to Go Next

- [API Reference](https://pub.dev/documentation/open_cdp_flutter_sdk/latest/)
- [Issue Tracker](https://github.com/yourusername/open_cdp_flutter_sdk/issues)
- [Example App](example/README.md) 