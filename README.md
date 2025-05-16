<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Open CDP Flutter SDK

A Flutter SDK for integrating Customer.io functionality into your Flutter applications.

## Features

- User identification and profile management
- Event tracking
- Push notification support
- Device attributes tracking
- Screen view tracking
- Metric tracking

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  open_cdp_flutter_sdk: ^1.0.0
  firebase_core: ^2.0.0
  firebase_messaging: ^14.0.0
```

## Setup

### Android

1. Add the following to your `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
}
```

2. Add the following to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS

1. Add the following to your `ios/Podfile`:

```ruby
pod 'Firebase/Messaging'
```

2. Add the following to your `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## Usage

### Initialize the SDK

```dart
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final config = OpenCDPConfig(
    apiKey: 'YOUR_API_KEY',
    region: Region.us,
    logLevel: OpenCDPLogLevel.debug,
    pushConfig: PushConfig(
      enabled: true,
      defaultNotificationChannelId: 'default',
      defaultNotificationChannelName: 'Default',
    ),
  );

  await OpenCDPSDK.initialize(config);
  runApp(MyApp());
}
```

### Identify Users

```dart
await OpenCDPSDK.instance.identify(
  'user123',
  attributes: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);
```

### Track Events

```dart
await OpenCDPSDK.instance.track(
  'purchase',
  properties: {
    'product_id': '123',
    'price': 99.99,
  },
);
```

### Track Screen Views

```dart
await OpenCDPSDK.instance.trackScreenView('Home Screen');
```

### Set Profile Attributes

```dart
await OpenCDPSDK.instance.setProfileAttributes({
  'name': 'John Doe',
  'email': 'john@example.com',
  'plan': 'premium',
});
```

### Set Device Attributes

```dart
await OpenCDPSDK.instance.setDeviceAttributes({
  'device_id': 'device123',
  'platform': 'ios',
  'app_version': '1.0.0',
});
```

### Handle Push Notifications

```dart
OpenCDPSDK.instance.onPushNotification.listen((RemoteMessage message) {
  print('Received push notification: ${message.notification?.title}');
});
```

### Track Metrics

```dart
await OpenCDPSDK.instance.trackMetric('delivery_rate', 0.95);
```

## Error Handling

The SDK provides error handling through try-catch blocks. All methods can throw exceptions that should be handled appropriately:

```dart
try {
  await OpenCDPSDK.instance.identify('user123');
} catch (e) {
  print('Error identifying user: $e');
}
```

## Logging

The SDK supports different log levels that can be configured during initialization:

```dart
final config = OpenCDPConfig(
  apiKey: 'YOUR_API_KEY',
  logLevel: OpenCDPLogLevel.debug, // Options: none, error, warn, info, debug
);
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
