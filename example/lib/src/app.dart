import 'package:flutter/material.dart';

import 'pages/initialization_page.dart';

class OpenCDPExampleApp extends StatelessWidget {
  const OpenCDPExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCDP SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Color(0xFFFAFAFA),
        ),
      ),
      home: const InitializationPage(),
    );
  }
}
