import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

import 'in_app_renderers.dart';

/// Wraps a [child] subtree and overlays in-app messages emitted by
/// [OpenCDPSDK.instance.inApp]. Modal renderers use a dialog, banners use a
/// transient overlay, and `inline` / `inbox_card` deliveries are pushed into
/// [onInlineMessage] so the host can render them in-place (e.g. inbox tab).
class InAppHost extends StatefulWidget {
  const InAppHost({
    super.key,
    required this.child,
    this.onInlineMessage,
  });

  final Widget child;

  /// Called for `inline` and `inbox_card` deliveries. Tracking impression /
  /// click / dismiss for these is the host's responsibility because they are
  /// rendered inside the host's own UI.
  final void Function(InAppMessage message)? onInlineMessage;

  @override
  State<InAppHost> createState() => _InAppHostState();
}

class _InAppHostState extends State<InAppHost> {
  StreamSubscription<InAppMessage>? _subscription;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    final manager = OpenCDPSDK.instance.inApp;
    if (manager == null) {
      debugPrint(
          '[CDPTest] In-app manager is null — initialize the SDK first.');
      return;
    }
    _subscription = manager.messageStream.listen(_handleMessage);
  }

  Future<void> _handleMessage(InAppMessage message) async {
    if (!mounted) return;
    final manager = OpenCDPSDK.instance.inApp;
    if (manager == null) return;

    switch (message.renderType) {
      case InAppRenderType.modal:
        await _showModal(manager, message);
        break;
      case InAppRenderType.banner:
        await _showBanner(manager, message);
        break;
      case InAppRenderType.inline:
      case InAppRenderType.inboxCard:
        widget.onInlineMessage?.call(message);
        break;
      case InAppRenderType.unknown:
        debugPrint(
            '[CDPTest] Skipping unknown render type for ${message.deliveryId}');
        break;
    }
  }

  Future<void> _showModal(CDPInAppManager manager, InAppMessage message) async {
    // Open the dialog synchronously so we can avoid async-context-gap lints,
    // then track the impression in parallel with the user reading the dialog.
    final dialogFuture = showDialog<String?>(
      context: context,
      builder: (_) => InAppModalDialog(message: message),
    );
    unawaited(manager.trackImpression(message));

    final actionId = await dialogFuture;
    if (actionId != null && actionId.isNotEmpty) {
      await manager.trackClick(message: message, actionId: actionId);
    } else {
      await manager.trackDismiss(
        message: message,
        reason: InAppDismissReason.userClose,
      );
    }
  }

  Future<void> _showBanner(
      CDPInAppManager manager, InAppMessage message) async {
    _dismissBanner(track: false);

    // Resolve the overlay before any awaits so we don't hit
    // use_build_context_synchronously lints.
    final overlay = Overlay.of(context, rootOverlay: true);
    unawaited(manager.trackImpression(message));

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: InAppBanner(
              message: message,
              onPrimaryCta: (cta) async {
                await manager.trackClick(message: message, actionId: cta.id);
                _dismissBanner(track: false);
              },
              onClose: () async {
                await manager.trackDismiss(
                  message: message,
                  reason: InAppDismissReason.userClose,
                );
                _dismissBanner(track: false);
              },
            ),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);

    _bannerTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      manager.trackDismiss(
        message: message,
        reason: InAppDismissReason.expired,
      );
      _dismissBanner(track: false);
    });
  }

  void _dismissBanner({bool track = false}) {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissBanner(track: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
