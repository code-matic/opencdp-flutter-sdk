import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import '../components/console_view.dart';
import '../services/log_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actions', icon: Icon(Icons.touch_app)),
            Tab(text: 'Logs', icon: Icon(Icons.list_alt)),
            Tab(text: 'Info', icon: Icon(Icons.info_outline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // In a real app we might want to un-init, but SDK doesn't support un-init.
              // Just pop back to config page.
              Navigator.of(context).pop();
            },
            tooltip: 'Re-configure',
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ActionsTab(),
          ConsoleView(),
          _InfoTab(),
        ],
      ),
    );
  }
}

class _ActionsTab extends StatefulWidget {
  const _ActionsTab();

  @override
  State<_ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<_ActionsTab> {
  final _userIdController = TextEditingController(text: 'user_001');
  final _traitsController = TextEditingController(text: '{"plan": "premium"}');
  final _eventController = TextEditingController(text: 'button_clicked');
  final _propsController = TextEditingController(text: '{"id": 123}');
  final _screenController = TextEditingController(text: 'Settings Page');

  void _log(String msg, {LogType type = LogType.info}) =>
      LogService.instance.log(msg, type: type);

  Map<String, dynamic> _parseJson(String text) {
    try {
      if (text.isEmpty) return {};
      return jsonDecode(text);
    } catch (e) {
      _log('JSON Parse Error: $e', type: LogType.error);
      return {};
    }
  }

  Future<void> _identify() async {
    final id = _userIdController.text;
    if (id.isEmpty) {
      _log('User ID required', type: LogType.error);
      return;
    }
    await OpenCDPSDK.instance.identify(
        identifier: id, properties: _parseJson(_traitsController.text));
    _log('Identified user: $id', type: LogType.success);
    setState(
        () {}); // Refresh info tab if we were watching it (though we are on actions tab)
  }

  Future<void> _clearIdentity() async {
    await OpenCDPSDK.instance.clearIdentity();
    _log('Identity cleared', type: LogType.success);
    setState(() {});
  }

  Future<void> _track() async {
    final event = _eventController.text;
    if (event.isEmpty) return;
    await OpenCDPSDK.instance.track(
      eventName: event,
      properties: _parseJson(_propsController.text),
    );
    _log('Tracked event: $event', type: LogType.success);
  }

  Future<void> _trackScreen() async {
    final screen = _screenController.text;
    if (screen.isEmpty) return;
    await OpenCDPSDK.instance.trackScreenView(title: screen);
    _log('Tracked screen: $screen', type: LogType.success);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(title: 'Identity', children: [
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
                labelText: 'User ID', prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _traitsController,
            decoration: const InputDecoration(
                labelText: 'Traits (JSON)', prefixIcon: Icon(Icons.code)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: FilledButton(
                      onPressed: _identify, child: const Text('Identify'))),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clearIdentity,
                child: const Text('Clear'),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 24),
        _Section(title: 'Events', children: [
          TextField(
            controller: _eventController,
            decoration: const InputDecoration(
                labelText: 'Event Name', prefixIcon: Icon(Icons.touch_app)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _propsController,
            decoration: const InputDecoration(
                labelText: 'Properties (JSON)',
                prefixIcon: Icon(Icons.data_object)),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _track, child: const Text('Track Event')),
        ]),
        const SizedBox(height: 24),
        _Section(title: 'Screens', children: [
          TextField(
            controller: _screenController,
            decoration: const InputDecoration(
                labelText: 'Screen Name', prefixIcon: Icon(Icons.screen_share)),
          ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _trackScreen, child: const Text('Track Screen View')),
        ]),
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context) {
    // Note: This won't auto-update unless we wrap it in a stream or listenable
    // But for simplicity in this example we just show current state on build
    final userId = OpenCDPSDK.instance.userId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Current User ID'),
          subtitle: Text(userId ?? 'Anonymous'),
          leading: Icon(userId != null ? Icons.person : Icons.person_off),
        ),
        const Divider(),
        ListTile(
          title: const Text('Screen Tracking'),
          subtitle: Text(OpenCDPSDK.instance.screenTracker != null
              ? 'Active'
              : 'Disabled'),
          leading: const Icon(Icons.visibility),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
