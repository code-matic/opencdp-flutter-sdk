import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the SDK
  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: 'your-cdp-api-key',
      cdpEndpoint: 'https://api.opencdp.com', // Optional custom endpoint
      debug: true,
      autoTrackDeviceAttributes: true,
      autoTrackScreens: true, // Enable automatic screen tracking
      trackApplicationLifecycleEvents: true,
      screenViewUse: ScreenView.all,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open CDP SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
      // Add the screen tracker to the navigator observers
      navigatorObservers: [
        if (OpenCDPSDK.instance.screenTracker != null)
          OpenCDPSDK.instance.screenTracker!,
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoggedIn = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    // Request permission for push notifications
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        // Store token to send to backend when user logs in
        _fcmToken = token;
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((token) {
        debugPrint('FCM Token refreshed: $token');
        _fcmToken = token;
        // Send new token to backend if user is logged in
        if (_userId != null) {
          _registerDeviceToken();
        }
      });
    }
  }

  String? _fcmToken;

  Future<void> _registerDeviceToken() async {
    if (_userId != null && _fcmToken != null) {
      await OpenCDPSDK.instance.registerDeviceToken(_userId!, _fcmToken!);
    }
  }

  Future<void> _login() async {
    const userId = 'user123';

    // Identify user
    await OpenCDPSDK.instance.identify(
      userId,
      properties: {
        'name': 'John Doe',
        'email': 'john@example.com',
      },
    );

    // Update user properties
    await OpenCDPSDK.instance.update(
      userId,
      {
        'tier': 'premium',
        'subscriptionStatus': 'active',
        'lastLoginDate': DateTime.now().toIso8601String(),
      },
    );

    // Register device token if available
    if (_fcmToken != null) {
      await _registerDeviceToken();
    }

    setState(() {
      _isLoggedIn = true;
      _userId = userId;
    });
  }

  Future<void> _logout() async {
    if (_userId != null) {
      // Update user properties before logout
      await OpenCDPSDK.instance.update(
        _userId!,
        {
          'lastLogoutDate': DateTime.now().toIso8601String(),
        },
      );
    }

    setState(() {
      _isLoggedIn = false;
      _userId = null;
    });
  }

  Future<void> _trackEvent() async {
    if (_userId != null) {
      await OpenCDPSDK.instance.track(
        _userId!,
        'button_clicked',
        properties: {
          'buttonName': 'track_event',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> _trackScreen() async {
    if (_userId != null) {
      await OpenCDPSDK.instance.screen(
        _userId!,
        'Home Screen',
        properties: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open CDP SDK Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isLoggedIn)
              ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              )
            else
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Logout'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _trackEvent,
              child: const Text('Track Event'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _trackScreen,
              child: const Text('Track Screen View'),
            ),
          ],
        ),
      ),
    );
  }
}
