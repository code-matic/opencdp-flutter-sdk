import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'config_screen.dart';
import 'home_screen.dart';

/// Test harness for the OpenCDP Flutter SDK in-app messaging feature.
///
/// The app boots into a configuration screen so you can point it at any
/// workspace (local, staging, prod) without rebuilding. Once initialized, the
/// home screen is wrapped in [OpenCDPInAppHost] so modal/banner auto-present
/// and inline/inbox slots receive layout-bound messages.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TestApp());
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  bool _initialized = false;
  String? _personId;

  void _onInitialized(String personId) {
    setState(() {
      _initialized = true;
      _personId = personId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCDP In-App Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Mount OpenCDPInAppHost only after SDK init — the host attaches to
      // OpenCDPSDK.instance.inApp in initState.
      home: _initialized && _personId != null
          ? OpenCDPInAppHost(
              child: HomeScreen(personId: _personId!),
            )
          : ConfigScreen(onInitialized: _onInitialized),
    );
  }
}
