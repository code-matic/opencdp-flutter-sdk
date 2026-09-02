import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/in_app_manager.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/open_cdp_in_app_slot_registry.dart';
import 'package:open_cdp_flutter_sdk/src/in_app/open_cdp_in_app_widgets.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

/// Place this **in the widget tree** where an inline message should appear
/// (e.g. above a balance row). Not GlobalKey hunting — you choose the spot.
///
/// Requires an ancestor [OpenCDPInAppHost].
///
/// Optional [slotId]: when the host publishes with a matching
/// `targetSlotId`, only that slot shows the message. When the host
/// publishes with no target, every [OpenCDPInAppInlineSlot] can show it
/// (use one slot per screen).
class OpenCDPInAppInlineSlot extends StatefulWidget {
  const OpenCDPInAppInlineSlot({
    super.key,
    this.slotId,
    this.builder,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  /// Optional placement id for multi-slot screens.
  final String? slotId;

  /// Custom UI. Return a widget that calls [onCta]/[onDismiss] as needed.
  final Widget Function(
    BuildContext context,
    InAppMessage message, {
    required VoidCallback onCta,
    required VoidCallback onDismiss,
  })? builder;

  final EdgeInsetsGeometry padding;

  @override
  State<OpenCDPInAppInlineSlot> createState() => _OpenCDPInAppInlineSlotState();
}

class _OpenCDPInAppInlineSlotState extends State<OpenCDPInAppInlineSlot> {
  String? _impressedFor;

  Future<void> _ensureImpression(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    if (_impressedFor == message.deliveryId) return;
    if (!registry.markImpressed(message.deliveryId)) {
      _impressedFor = message.deliveryId;
      return;
    }
    _impressedFor = message.deliveryId;
    await registry.trackImpression?.call(message);
  }

  Future<void> _onCta(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    final cta = message.primaryCta;
    if (cta != null) {
      await registry.trackClick?.call(message, cta.id);
    }
    registry.clearInline();
  }

  Future<void> _onDismiss(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    await registry.trackDismiss?.call(
      message,
      InAppDismissReason.userClose,
    );
    registry.clearInline();
  }

  @override
  Widget build(BuildContext context) {
    final registry = OpenCDPInAppSlotScope.maybeOf(context);
    if (registry == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final message = registry.inlineForSlot(widget.slotId);
        if (message == null) return const SizedBox.shrink();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureImpression(registry, message);
        });

        void onCta() => _onCta(registry, message);
        void onDismiss() => _onDismiss(registry, message);
        final child = widget.builder != null
            ? widget.builder!(
                context,
                message,
                onCta: onCta,
                onDismiss: onDismiss,
              )
            : OpenCDPInAppInlineCard(
                message: message,
                onCta: onCta,
                onDismiss: onDismiss,
              );

        return Padding(padding: widget.padding, child: child);
      },
    );
  }
}

/// Place in a scrollable column / list to append inbox-style cards.
///
/// Requires an ancestor [OpenCDPInAppHost].
class OpenCDPInAppInboxSlot extends StatelessWidget {
  const OpenCDPInAppInboxSlot({
    super.key,
    this.builder,
    this.itemPadding = const EdgeInsets.only(bottom: 8),
    this.separator,
  });

  final Widget Function(
    BuildContext context,
    InAppMessage message, {
    required VoidCallback onCta,
    required VoidCallback onDismiss,
  })? builder;

  final EdgeInsetsGeometry itemPadding;
  final Widget? separator;

  Future<void> _onCta(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    final cta = message.primaryCta;
    if (cta != null) {
      await registry.trackClick?.call(message, cta.id);
    }
    registry.removeInbox(message.deliveryId);
  }

  Future<void> _onDismiss(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    await registry.trackDismiss?.call(
      message,
      InAppDismissReason.userClose,
    );
    registry.removeInbox(message.deliveryId);
  }

  Future<void> _ensureImpression(
    OpenCDPInAppSlotRegistry registry,
    InAppMessage message,
  ) async {
    if (!registry.markImpressed(message.deliveryId)) return;
    await registry.trackImpression?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    final registry = OpenCDPInAppSlotScope.maybeOf(context);
    if (registry == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final messages = registry.inboxMessages;
        if (messages.isEmpty) return const SizedBox.shrink();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final m in messages) {
            _ensureImpression(registry, m);
          }
        });

        final children = <Widget>[];
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          void onCta() => _onCta(registry, message);
          void onDismiss() => _onDismiss(registry, message);
          final card = builder != null
              ? builder!(
                  context,
                  message,
                  onCta: onCta,
                  onDismiss: onDismiss,
                )
              : OpenCDPInAppInlineCard(
                  message: message,
                  onCta: onCta,
                  onDismiss: onDismiss,
                );
          children.add(Padding(padding: itemPadding, child: card));
          if (separator != null && i < messages.length - 1) {
            children.add(separator!);
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
