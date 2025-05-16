import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();

  // Initialize the SDK
  await OpenCDPSDK.initialize(
    config: OpenCDPConfig(
      cdpApiKey: 'YOUR_CDP_API_KEY',
      debug: true,
      autoTrackScreens: true,
      autoTrackDeviceAttributes: true,
      sendToCustomerIo: true,
      customerIo: CustomerIoConfig(
        siteId: 'YOUR_CUSTOMER_IO_SITE_ID',
        apiKey: 'YOUR_CUSTOMER_IO_API_KEY',
      ),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCDP SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      navigatorObservers: [
        OpenCDPSDK.instance.screenTracker!,
      ],
      home: const MyHomePage(title: 'OpenCDP SDK Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() async {
    setState(() {
      _counter++;
    });

    // Identify user
    await OpenCDPSDK.instance.identify(
      identifier: 'user_123',
      properties: {
        'name': 'John Doe',
        'email': 'john@example.com',
      },
    );

    // Track event
    await OpenCDPSDK.instance.track(
      identifier: 'user_123',
      eventName: 'button_clicked',
      properties: {
        'button_name': 'increment',
        'count': _counter,
      },
    );

    // Update user properties
    await OpenCDPSDK.instance.update(
      identifier: 'user_123',
      properties: {
        'last_clicked': DateTime.now().toIso8601String(),
        'total_clicks': _counter,
      },
    );

    // Register device (example with dummy tokens)
    await OpenCDPSDK.instance.registerDeviceToken(
      identifier: 'user_123',
      fcmToken: 'dummy_fcm_token',
      apnToken: 'dummy_apn_token',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
