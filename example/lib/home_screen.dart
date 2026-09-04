import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'events/events_screen.dart';
import 'in_app/in_app_lab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.personId});

  final String personId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'In-App' : 'Events')),
      body: SafeArea(
        child: _tab == 0
            ? InAppLabScreen(personId: widget.personId)
            : const EventsScreen(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          OpenCDPSDK.instance.inApp?.setCurrentScreen(i == 0 ? 'home' : 'events');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.message), label: 'In-App'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Events'),
        ],
      ),
    );
  }
}
