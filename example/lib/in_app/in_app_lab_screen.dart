import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// Minimal in-app demo: screen chips, sync, inline + inbox slots.
/// Modal/banner come from the parent [OpenCDPInAppHost].
class InAppLabScreen extends StatefulWidget {
  const InAppLabScreen({super.key, required this.personId});

  final String personId;

  @override
  State<InAppLabScreen> createState() => _InAppLabScreenState();
}

class _InAppLabScreenState extends State<InAppLabScreen> {
  static const _screens = ['home', 'cart', 'profile', 'inbox', 'checkout'];
  String _screen = _screens.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setScreen(_screen));
  }

  Future<void> _setScreen(String screen) async {
    setState(() => _screen = screen);
    await OpenCDPSDK.instance.inApp?.setCurrentScreen(screen);
  }

  @override
  Widget build(BuildContext context) {
    final inApp = OpenCDPSDK.instance.inApp;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${widget.personId} · $_screen'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in _screens)
              ChoiceChip(
                label: Text(s),
                selected: _screen == s,
                onSelected: (v) {
                  if (v) _setScreen(s);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              onPressed: () => inApp?.syncNow(),
              child: const Text('Sync'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => inApp?.resetSession(),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Inline'),
        const OpenCDPInAppInlineSlot(slotId: 'lab_inline'),
        const SizedBox(height: 16),
        const Text('Inbox'),
        const OpenCDPInAppInboxSlot(),
      ],
    );
  }
}
