import 'package:flutter/material.dart';

import 'config_screen.dart';
import 'home_screen.dart';

/// Test harness for the OpenCDP Flutter SDK in-app messaging feature.
///
/// The app boots into a configuration screen so you can point it at any
/// workspace (local, staging, prod) without rebuilding. Once initialized, the
/// home screen drives identify/navigation/manual-sync flows and the in-app
/// host overlays whatever the SDK delivers.
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
          ? HomeScreen(personId: _personId!)
          : ConfigScreen(onInitialized: _onInitialized),
    );
  }
}
