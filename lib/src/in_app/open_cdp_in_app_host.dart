import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// Builds a modal body for [showDialog]. Pop with a CTA `id` (String) or
/// `null` when the user dismisses without a CTA — the host tracks click/dismiss.
typedef OpenCDPInAppModalBuilder = Widget Function(
  BuildContext context,
  InAppMessage message,
);

/// Builds a banner overlay widget. Call [onPrimaryCta] / [onClose] so the host
/// can track and remove the overlay.
typedef OpenCDPInAppBannerBuilder = Widget Function(
  BuildContext context,
  InAppMessage message, {
  required void Function(InAppCta cta) onPrimaryCta,
  required VoidCallback onClose,
});

/// App-wide entry point that listens to [OpenCDPSDK.instance.inApp] and
/// presents `modal` / `banner` messages automatically, and publishes
/// `inline` / `inbox_card` into [OpenCDPInAppSlotRegistry] for
/// [OpenCDPInAppInlineSlot] / [OpenCDPInAppInboxSlot].
///
/// Include / Exclude targeting is applied by the backend on `/sync?screen=…`
/// (keep [OpenCDPConfig.autoTrackScreens] + navigator observers, or call
/// [CDPInAppManager.setCurrentScreen] yourself).
///
/// ## Placement (routing-agnostic)
///
/// Prefer wrapping [MaterialApp.builder] / [CupertinoApp.builder] **and**
/// passing the same [navigatorKey] attached to that app (or GoRouter):
///
/// ```dart
/// final navKey = GlobalKey<NavigatorState>();
///
/// MaterialApp(
///   navigatorKey: navKey,
///   builder: (context, child) => OpenCDPInAppHost(
///     navigatorKey: navKey,
///     child: child!,
///     modalBuilder: (context, message) => MyModal(message: message),
///   ),
/// );
/// ```
///
/// With [navigatorKey], modal / banner present via that navigator even when
/// this host sits *above* the navigator (the usual `builder` case). Without
/// a key, mount the host **under** a [Navigator] instead (e.g. as `home` or
/// inside a GoRouter shell).
///
/// Prefer enabling [OpenCDPConfig.enableInAppAutoPresent] together with
/// [OpenCDPConfig.enableInAppMessages]. When auto-present is false, modal /
/// banner are skipped unless [forcePresent] is true; **slots still receive**
/// inline / inbox messages whenever this host is mounted.
class OpenCDPInAppHost extends StatefulWidget {
  const OpenCDPInAppHost({
    super.key,
    required this.child,
    this.navigatorKey,
    this.onInlineMessage,
    this.onInboxMessage,
    this.modalBuilder,
    this.bannerBuilder,
    this.forcePresent = false,
  });

  final Widget child;

  /// Same [GlobalKey] passed to [MaterialApp.navigatorKey],
  /// [CupertinoApp.navigatorKey], or [GoRouter.navigatorKey].
  ///
  /// When set, modal / banner use this navigator for [showDialog] / [Overlay]
  /// so the host may live in `MaterialApp.builder` (above the navigator).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Called for [InAppRenderType.inline] (in addition to slot registry).
  ///
  /// Also receives [InAppRenderType.inboxCard] when [onInboxMessage] is null
  /// (backward-compatible single-callback hosts). Prefer [onInboxMessage] when
  /// you need separate handling.
  final void Function(InAppMessage message)? onInlineMessage;

  /// Called for [InAppRenderType.inboxCard] (in addition to slot registry).
  ///
  /// When null, inbox deliveries fall back to [onInlineMessage] if set.
  final void Function(InAppMessage message)? onInboxMessage;

  /// Custom modal UI. If null, the SDK default [OpenCDPInAppModalDialog] is used.
  /// The returned widget should `Navigator.pop(context, ctaIdOrNull)`.
  final OpenCDPInAppModalBuilder? modalBuilder;

  /// Custom banner UI. If null, the SDK default [OpenCDPInAppBanner] is used.
  final OpenCDPInAppBannerBuilder? bannerBuilder;

  /// When true, present modal/banner even if
  /// [OpenCDPConfig.enableInAppAutoPresent] is false.
  final bool forcePresent;

  @override
  State<OpenCDPInAppHost> createState() => _OpenCDPInAppHostState();
}

class _OpenCDPInAppHostState extends State<OpenCDPInAppHost> {
  final OpenCDPInAppSlotRegistry _registry = OpenCDPInAppSlotRegistry();
  StreamSubscription<InAppMessage>? _subscription;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;
  bool _modalShowing = false;
  InAppMessage? _pendingModal;

  bool get _shouldPresentOverlay {
    if (widget.forcePresent) return true;
    return OpenCDPSDK.instance.config?.enableInAppAutoPresent ?? false;
  }

  void _debugLog(String message) {
    if (OpenCDPSDK.instance.config?.debug ?? false) {
      debugPrint(message);
    }
  }

  /// Context that can resolve a [Navigator] / [Overlay] for presentation.
  ///
  /// When [OpenCDPInAppHost.navigatorKey] is set, only that navigator's context
  /// is used. Falling back to the host context would succeed immediately in
  /// `MaterialApp.builder` (above the navigator) and skip the wait for the key.
  BuildContext? _presentContext() {
    final key = widget.navigatorKey;
    if (key != null) return key.currentContext;
    if (!mounted) return null;
    return context;
  }

  OverlayState? _presentOverlay() {
    final navState = widget.navigatorKey?.currentState;
    if (navState?.overlay != null) return navState!.overlay;
    final ctx = _presentContext();
    if (ctx == null) return null;
    return Overlay.maybeOf(ctx, rootOverlay: true);
  }

  @override
  void initState() {
    super.initState();
    _wireRegistryTracking();
    _attach();
  }

  void _wireRegistryTracking() {
    _registry.trackImpression = (message) async {
      final manager = OpenCDPSDK.instance.inApp;
      if (manager == null) return;
      await manager.trackImpression(message);
    };
    _registry.trackClick = (message, actionId) async {
      final manager = OpenCDPSDK.instance.inApp;
      if (manager == null) return;
      await manager.trackClick(message: message, actionId: actionId);
    };
    _registry.trackDismiss = (message, reason) async {
      final manager = OpenCDPSDK.instance.inApp;
      if (manager == null) return;
      await manager.trackDismiss(message: message, reason: reason);
    };
  }

  void _attach() {
    final manager = OpenCDPSDK.instance.inApp;
    if (manager == null) {
      _debugLog(
        '[CDP] OpenCDPInAppHost: in-app manager is null — '
        'enableInAppMessages and initialize the SDK first.',
      );
      return;
    }
    if (!_shouldPresentOverlay) {
      _debugLog(
        '[CDP] OpenCDPInAppHost: enableInAppAutoPresent is false; '
        'modal/banner skipped (slots still active). '
        'Pass forcePresent: true to present overlays.',
      );
    }
    _subscription = manager.messageStream.listen(_handleMessage);
  }

  Future<void> _handleMessage(InAppMessage message) async {
    if (!mounted) return;
    final manager = OpenCDPSDK.instance.inApp;
    if (manager == null) return;

    switch (message.renderType) {
      case InAppRenderType.modal:
        if (!_shouldPresentOverlay) return;
        if (_modalShowing) {
          _pendingModal = message;
          return;
        }
        await _showModal(manager, message);
        break;
      case InAppRenderType.banner:
        if (!_shouldPresentOverlay) return;
        await _showBanner(manager, message);
        break;
      case InAppRenderType.inline:
        _registry.setInline(message);
        widget.onInlineMessage?.call(message);
        break;
      case InAppRenderType.inboxCard:
        _registry.addInbox(message);
        // Prefer onInboxMessage; fall back to onInlineMessage for hosts that
        // use a single callback for both layout-bound render types.
        (widget.onInboxMessage ?? widget.onInlineMessage)?.call(message);
        break;
      case InAppRenderType.unknown:
        _debugLog(
          '[CDP] OpenCDPInAppHost: skipping unknown render type '
          'for ${message.deliveryId}',
        );
        break;
    }
  }

  Future<BuildContext?> _waitForPresentContext() async {
    var ctx = _presentContext();
    if (ctx != null) return ctx;
    // Navigator may not be ready on the same frame the host mounts.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    ctx = _presentContext();
    if (ctx == null) {
      _debugLog(
        '[CDP] OpenCDPInAppHost: no Navigator context for modal/banner — '
        'pass navigatorKey (same key as MaterialApp/GoRouter) or mount '
        'the host under a Navigator.',
      );
    }
    return ctx;
  }

  Future<void> _showModal(CDPInAppManager manager, InAppMessage message) async {
    _modalShowing = true;
    final presentContext = await _waitForPresentContext();
    if (presentContext == null || !mounted) {
      _modalShowing = false;
      return;
    }

    final dialogFuture = showDialog<String?>(
      context: presentContext,
      useRootNavigator: true,
      builder: (dialogContext) {
        final custom = widget.modalBuilder;
        if (custom != null) {
          return custom(dialogContext, message);
        }
        return OpenCDPInAppModalDialog(message: message);
      },
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
    _modalShowing = false;
    final pending = _pendingModal;
    _pendingModal = null;
    if (pending != null && mounted) {
      await _showModal(manager, pending);
    }
  }

  Future<void> _showBanner(
    CDPInAppManager manager,
    InAppMessage message,
  ) async {
    // Wait before dismissing. Two deliveries can pass this await together;
    // dismissing first lets both resume and insert, and the earlier timer
    // then removes the later banner.
    await _waitForPresentContext();
    if (!mounted) return;

    final overlay = _presentOverlay();
    if (overlay == null) {
      _debugLog(
        '[CDP] OpenCDPInAppHost: no Overlay for banner — '
        'pass navigatorKey or mount the host under a Navigator.',
      );
      return;
    }

    _dismissBanner();

    unawaited(manager.trackImpression(message));

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildBanner(overlayContext, manager, message),
          ),
        ),
      ),
    );
    _bannerEntry = entry;
    overlay.insert(entry);

    _bannerTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _bannerEntry != entry) return;
      unawaited(
        manager.trackDismiss(
          message: message,
          reason: InAppDismissReason.expired,
        ),
      );
      _dismissBanner();
    });
  }

  Widget _buildBanner(
    BuildContext context,
    CDPInAppManager manager,
    InAppMessage message,
  ) {
    void onPrimaryCta(InAppCta cta) {
      unawaited(manager.trackClick(message: message, actionId: cta.id));
      _dismissBanner();
    }

    void onClose() {
      unawaited(
        manager.trackDismiss(
          message: message,
          reason: InAppDismissReason.userClose,
        ),
      );
      _dismissBanner();
    }

    final custom = widget.bannerBuilder;
    if (custom != null) {
      return custom(
        context,
        message,
        onPrimaryCta: onPrimaryCta,
        onClose: onClose,
      );
    }
    return OpenCDPInAppBanner(
      message: message,
      onPrimaryCta: onPrimaryCta,
      onClose: onClose,
    );
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissBanner();
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OpenCDPInAppSlotScope(
      registry: _registry,
      child: widget.child,
    );
  }
}
