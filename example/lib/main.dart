import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'config_screen.dart';
import 'home_screen.dart';

/// Config first, then [OpenCDPInAppHost] + [HomeScreen] (In-App / Events).
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
      home: _initialized && _personId != null
          ? OpenCDPInAppHost(child: HomeScreen(personId: _personId!))
          : ConfigScreen(onInitialized: _onInitialized),
    );
  }
}
