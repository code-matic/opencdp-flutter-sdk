# Open CDP Flutter SDK Example

This example demonstrates how to integrate and use the Open CDP Flutter SDK in a Flutter application.

## Features Demonstrated

- SDK initialization with configuration
- User identification and profile management
- Event tracking
- Push notification handling
- Device attributes tracking

## Setup

1. Configure Firebase:
   - Create a new Firebase project
   - Add your Android and iOS apps
   - Download and add the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS

2. Update the SDK configuration:
   - Replace `'your-api-key'` in `main.dart` with your actual CDP API key
   - Configure other settings as needed

3. Run the app:
   ```bash
   flutter pub get
   flutter run
   ```

## Usage

The example app demonstrates:

1. **Login/Logout**
   - Identifies a user with traits
   - Sets profile and device attributes
   - Clears user identification on logout

2. **Event Tracking**
   - Tracks button clicks with properties
   - Demonstrates screen view tracking

3. **Push Notifications**
   - Listens for incoming push notifications
   - Logs notification details to console

## Notes

- The example uses Firebase Cloud Messaging for push notifications
- Make sure to configure Firebase properly for your platform
- The SDK configuration can be customized based on your needs 