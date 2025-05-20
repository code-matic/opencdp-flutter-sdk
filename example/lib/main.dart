import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the SDK
  await OpenCDPSDK.initialize(
    config: const OpenCDPConfig(
      cdpApiKey: 'your-api-key',
      debug: true,
      autoTrackScreens: true,
      trackApplicationLifecycleEvents: true,
      autoTrackDeviceAttributes: true,
      sendToCustomerIo: true,
      customerIo: CustomerIoConfig(
        siteId: 'your-site-id',
        apiKey: 'your-customer-io-api-key',
        customerIoRegion: Region.us,
        autoTrackDeviceAttributes: true,
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
      title: 'Open CDP SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorObservers: [
        OpenCDPSDK.instance.screenTracker!,
      ],
      home: const MyHomePage(title: 'Open CDP SDK Example'),
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
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  void _loadUserId() {
    // This is a dummy implementation
    // In a real app, you would use SharedPreferences to load the user ID
    setState(() {
      _userId = 'user123'; // No stored user ID in this example
    });
  }

  Future<void> _identifyUser() async {
    try {
      await OpenCDPSDK.instance.identify(
        identifier: 'user123',
        properties: {
          'name': 'John Doe',
          'email': 'john@example.com',
        },
      );
      setState(() {
        _userId = 'user123';
      });
      _showSnackBar('User identified successfully');
    } catch (e) {
      _showSnackBar('Error identifying user: $e');
    }
  }

  Future<void> _trackEvent() async {
    if (_userId == null) {
      _showSnackBar('Please identify a user first');
      return;
    }

    try {
      await OpenCDPSDK.instance.track(
        eventName: 'button_clicked',
        properties: {
          'button_name': 'increment',
          'count': _counter,
        },
      );
      _showSnackBar('Event tracked successfully');
    } catch (e) {
      _showSnackBar('Error tracking event: $e');
    }
  }

  Future<void> _trackScreenView() async {
    if (_userId == null) {
      _showSnackBar('Please identify a user first');
      return;
    }

    try {
      await OpenCDPSDK.instance.trackScreenView(
        title: 'Home Page',
        properties: {
          'counter': _counter,
        },
      );
      _showSnackBar('Screen view tracked successfully');
    } catch (e) {
      _showSnackBar('Error tracking screen view: $e');
    }
  }

  Future<void> _updateUserProperties() async {
    if (_userId == null) {
      _showSnackBar('Please identify a user first');
      return;
    }

    try {
      await OpenCDPSDK.instance.update(
        properties: {
          'last_clicked': DateTime.now().toIso8601String(),
          'total_clicks': _counter,
        },
      );
      _showSnackBar('User properties updated successfully');
    } catch (e) {
      _showSnackBar('Error updating user properties: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'User ID: ${_userId ?? 'Not identified'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text(
              'You have pushed the button this many times:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _identifyUser,
              child: const Text('Identify User'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _trackEvent,
              child: const Text('Track Event'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _trackScreenView,
              child: const Text('Track Screen View'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _updateUserProperties,
              child: const Text('Update User Properties'),
            ),
            const SizedBox(height: 20),
            Text(
              'Auto-tracking enabled:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '• Screen views are automatically tracked\n• App lifecycle events are automatically tracked',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _counter++;
          });
          _trackEvent();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
