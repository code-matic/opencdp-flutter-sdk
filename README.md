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

# OpenCDP Flutter SDK

A Flutter SDK for integrating with the OpenCDP platform. This SDK provides a simple, flexible way to track user events, identify users, and manage device tokens in your Flutter applications.

---

## Features

- **User Identification**: Easily identify users and associate traits.
- **Event Tracking**: Track custom events and screen views.
- **Anonymous & Identified Tracking**: Supports both anonymous and identified user journeys.
- **Device Token Registration**: Register device tokens for push notifications.
- **Automatic Device Attribute Tracking**: Collect device and app info automatically.
- **Automatic Screen Tracking**: Track screen views with a single configuration.
- **Customer.io Integration**: Optional integration with Customer.io for advanced messaging.
- **Configurable Debug Logging**: Enable verbose logging for development and debugging.

---

## Installation

### From pub.dev

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  open_cdp_flutter_sdk: ^1.0.0
```

Then run:

```sh
flutter pub get
```

### From Git Repository

To use the SDK directly from the Git repository, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  open_cdp_flutter_sdk:
    git:
      url: https://github.com/code-matic/opencdp-flutter-sdk.git
      ref: main  # or any other branch/tag/commit
```

Then run:

```sh
flutter pub get
```

---

## Usage

### 1. Initialize the SDK

```dart
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: 'YOUR_CDP_API_KEY',
      debug: true,
      autoTrackScreens: true,
      autoTrackDeviceAttributes: true,
      sendToCustomerIo: true, // Optional
      customerIo: CustomerIoConfig(
        siteId: 'YOUR_CUSTOMER_IO_SITE_ID',
        apiKey: 'YOUR_CUSTOMER_IO_API_KEY',
      ),
    ),
  );

  runApp(MyApp());
}
```

### 2. Identify Users

```dart
await OpenCDPSDK.instance.identify(
  identifier: 'user_123',
  properties: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);
```

### 3. Track Events

```dart
await OpenCDPSDK.instance.track(
  identifier: 'user_123',
  eventName: 'button_clicked',
  properties: {
    'button_name': 'increment',
    'count': 5,
  },
);
```

### 4. Update User Properties

```dart
await OpenCDPSDK.instance.update(
  identifier: 'user_123',
  properties: {
    'last_clicked': DateTime.now().toIso8601String(),
    'total_clicks': 10,
  },
);
```

### 5. Register Device Token

```dart
await OpenCDPSDK.instance.registerDeviceToken(
  identifier: 'user_123',
  fcmToken: 'your_fcm_token', // For Android
  apnToken: 'your_apn_token', // For iOS
);
```

### 6. Automatic Screen Tracking

To enable automatic screen tracking, add the screen tracker to your app's navigator observers:

```dart
MaterialApp(
  navigatorObservers: [
    OpenCDPSDK.instance.screenTracker!,
  ],
  // ... other app configuration
)
```

---

## Configuration Options

| Option                          | Type      | Description                                      | Default      |
|----------------------------------|-----------|--------------------------------------------------|--------------|
| `cdpApiKey`                     | String    | Your CDP API key (required)                      | –            |
| `cdpEndpoint`                   | String?   | Custom CDP endpoint (optional)                   | –            |
| `sendToCustomerIo`              | bool      | Enable Customer.io integration                   | false        |
| `customerIo`                    | CustomerIoConfig? | Customer.io configuration                  | –            |
| `debug`                         | bool      | Enable debug logging                             | false        |
| `autoTrackDeviceAttributes`      | bool      | Track device attributes automatically            | true         |
| `autoTrackScreens`              | bool      | Enable automatic screen tracking                 | false        |
| `trackApplicationLifecycleEvents`| bool      | Track app lifecycle events                       | true         |
| `screenViewUse`                 | ScreenView| Screen view tracking configuration               | ScreenView.all|

---

## Error Handling

All SDK methods throw a `CDPException` on failure. You can catch and handle these as needed:

```dart
try {
  await OpenCDPSDK.instance.identify(identifier: 'user_123');
} catch (e) {
  if (e is CDPException) {
    print('CDP Error: ${e.message}');
  } else {
    print('Unexpected error: $e');
  }
}
```

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
