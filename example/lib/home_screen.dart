import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'events/events_screen.dart';

/// Main demo surface. Lets you switch logical screens (so backend page rules
/// can target them), force a sync, reset the in-app session, and place
/// [OpenCDPInAppInlineSlot] / [OpenCDPInAppInboxSlot] where layout-bound
/// messages should appear.
///
/// Modal / banner are presented by the ancestor [OpenCDPInAppHost] (see
/// `main.dart`) using the SDK default widgets.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.personId});

  final String personId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Logical screen names sent on each sync. Backend page rules use these.
  // 'events' is the harness tab for firing arbitrary track() calls — kept as
  // its own screen so in-app overlays don't fight the events UI.
  static const _screens = ['home', 'cart', 'profile', 'inbox', 'events'];

  int _currentIndex = 0;
  String? _lastDebugResult;

  String get _currentScreen => _screens[_currentIndex];
  bool get _isEventsTab => _currentScreen == 'events';
  bool get _isInboxTab => _currentScreen == 'inbox';

  @override
  void initState() {
    super.initState();
    // Push the initial screen into the manager for the next sync / page rules.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OpenCDPSDK.instance.inApp?.setCurrentScreen(_currentScreen);
    });
  }

  Future<void> _onScreenChange(int index) async {
    setState(() => _currentIndex = index);
    await OpenCDPSDK.instance.inApp?.setCurrentScreen(_currentScreen);
  }

  Future<void> _syncNow() async {
    final manager = OpenCDPSDK.instance.inApp;
    if (manager == null) return;
    await manager.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync requested')),
    );
  }

  void _resetLocalState() {
    OpenCDPSDK.instance.inApp?.resetSession();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local in-app state reset')),
    );
  }

  void _showDebugSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _debugTestHostFailover() async {
    try {
      await OpenCDPSDK.instance.debugTestHostFailover();
      setState(() => _lastDebugResult = 'Host failover: success (see console)');
      _showDebugSnack('Host failover OK — check Debug Console for per-host logs');
    } catch (e) {
      setState(() => _lastDebugResult = 'Host failover failed: $e');
      _showDebugSnack('Host failover failed — see console');
    }
  }

  Future<void> _debugTestQueueRetry() async {
    await OpenCDPSDK.instance.debugTestQueueRetry();
    setState(
      () => _lastDebugResult =
          'Queue retry: POST queued (tap Recover queue next)',
    );
    _showDebugSnack('POST queued — watch console, then tap Recover queue');
  }

  Future<void> _debugDrainQueue() async {
    await OpenCDPSDK.instance.debugDrainQueue();
    setState(() => _lastDebugResult = 'Queue drain: recovery track sent');
    _showDebugSnack('Recovery track sent — queue drain logs in console');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEventsTab
              ? 'Events • test triggers'
              : 'In-App Test • $_currentScreen',
        ),
      ),
      body: SafeArea(
        child: _isEventsTab ? _buildEventsBody() : _buildInAppBody(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onScreenChange,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Events'),
        ],
      ),
    );
  }

  Widget _buildInAppBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusPanel(
            personId: widget.personId,
            screen: _currentScreen,
            debugResult: _lastDebugResult,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _resetLocalState,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset local state'),
                ),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text(
              'Debug: retry / failover',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _debugTestHostFailover,
                  child: const Text('Test host failover'),
                ),
                FilledButton.tonal(
                  onPressed: _debugTestQueueRetry,
                  child: const Text('Test queue retry'),
                ),
                FilledButton.tonal(
                  onPressed: _debugDrainQueue,
                  child: const Text('Recover queue'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _isInboxTab ? 'Inbox cards' : 'Inline slot',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // Layout-bound messages: inline on home/cart/profile, inbox feed
          // on the inbox tab. Modal/banner overlays come from OpenCDPInAppHost.
          if (_isInboxTab)
            const OpenCDPInAppInboxSlot()
          else
            OpenCDPInAppInlineSlot(
              slotId: '${_currentScreen}_above_content',
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _SlotHint(isInbox: _isInboxTab),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _StatusPanel(personId: widget.personId, screen: _currentScreen),
        ),
        const Expanded(child: EventsScreen()),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.personId,
    required this.screen,
    this.debugResult,
  });

  final String personId;
  final String screen;
  final String? debugResult;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Person id', personId),
            _row('Current screen', screen),
            if (debugResult != null) _row('Last debug', debugResult!),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _SlotHint extends StatelessWidget {
  const _SlotHint({required this.isInbox});

  final bool isInbox;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInbox ? Icons.inbox_outlined : Icons.view_agenda_outlined,
            size: 36,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            isInbox
                ? 'Inbox cards appear above when the gateway\n'
                    'delivers inbox_card messages for this screen.'
                : 'An inline card appears above when the gateway\n'
                    'delivers an inline message for this screen.\n'
                    'Modal / banner show as overlays automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
