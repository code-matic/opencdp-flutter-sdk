import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'events/events_screen.dart';
import 'in_app/in_app_host.dart';
import 'in_app/in_app_renderers.dart';

/// Main demo surface. Lets you switch logical screens (so backend page rules
/// can target them), force a sync, reset the in-app session, and see the
/// inline / inbox-card messages stack up.
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
  final List<InAppMessage> _inlineMessages = [];

  String get _currentScreen => _screens[_currentIndex];
  bool get _isEventsTab => _currentScreen == 'events';

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
    setState(_inlineMessages.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local in-app state reset')),
    );
  }

  Future<void> _trackInlineImpression(InAppMessage message) async {
    await OpenCDPSDK.instance.inApp?.trackImpression(message);
  }

  Future<void> _trackInlineClick(InAppMessage message, InAppCta cta) async {
    await OpenCDPSDK.instance.inApp?.trackClick(message: message, actionId: cta.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Click tracked: ${cta.id}')),
    );
  }

  Future<void> _dismissInline(InAppMessage message) async {
    await OpenCDPSDK.instance.inApp?.trackDismiss(
      message: message,
      reason: InAppDismissReason.userClose,
    );
    setState(() => _inlineMessages.removeWhere(
        (m) => m.deliveryId == message.deliveryId));
  }

  void _onInlineMessage(InAppMessage message) {
    if (_inlineMessages.any((m) => m.deliveryId == message.deliveryId)) return;
    setState(() => _inlineMessages.add(message));
    _trackInlineImpression(message);
  }

  @override
  Widget build(BuildContext context) {
    return InAppHost(
      onInlineMessage: _onInlineMessage,
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildInAppBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusPanel(personId: widget.personId, screen: _currentScreen),
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
          const SizedBox(height: 16),
          Text(
            'Inline / inbox messages',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _inlineMessages.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: _inlineMessages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final m = _inlineMessages[index];
                      return InAppCard(
                        message: m,
                        onPrimaryCta: (cta) => _trackInlineClick(m, cta),
                        onDismiss: () => _dismissInline(m),
                      );
                    },
                  ),
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
  const _StatusPanel({required this.personId, required this.screen});

  final String personId;
  final String screen;

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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(
            'No inline / inbox messages yet.\nQueue a campaign or hit “Test in-app” from the dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
