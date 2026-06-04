import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';

/// A simple modal dialog rendering for `InAppRenderType.modal` messages.
///
/// Returns the action id when a CTA was tapped, or `null` when the user
/// dismissed the modal without picking one.
class InAppModalDialog extends StatelessWidget {
  const InAppModalDialog({super.key, required this.message});

  final InAppMessage message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
              ),
            if (message.title != null && message.title!.isNotEmpty)
              Text(
                message.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message.body!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            const SizedBox(height: 16),
            if (message.ctas.isEmpty)
              FilledButton(
                onPressed: () => Navigator.of(context).pop<String?>(null),
                child: const Text('Close'),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  for (final cta in message.ctas)
                    FilledButton.tonal(
                      onPressed: () =>
                          Navigator.of(context).pop<String?>(cta.id),
                      child: Text(cta.label),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<String?>(null),
                    child: const Text('Close'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Top banner used for `InAppRenderType.banner` messages. Auto-dismissed by
/// the host after a few seconds; tapping the action button reports a click.
class InAppBanner extends StatelessWidget {
  const InAppBanner({
    super.key,
    required this.message,
    required this.onPrimaryCta,
    required this.onClose,
  });

  final InAppMessage message;
  final void Function(InAppCta cta)? onPrimaryCta;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final primary = message.ctas.isNotEmpty ? message.ctas.first : null;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.title != null && message.title!.isNotEmpty)
                    Text(
                      message.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (message.body != null && message.body!.isNotEmpty)
                    Text(
                      message.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (primary != null)
              TextButton(
                onPressed:
                    onPrimaryCta == null ? null : () => onPrimaryCta!(primary),
                child: Text(primary.label),
              ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline card that renders inside a host widget for `InAppRenderType.inline`
/// or `InAppRenderType.inboxCard` messages. The card itself is dumb — the
/// caller wires up impression/click/dismiss tracking.
class InAppCard extends StatelessWidget {
  const InAppCard({
    super.key,
    required this.message,
    required this.onPrimaryCta,
    this.onDismiss,
  });

  final InAppMessage message;
  final void Function(InAppCta cta)? onPrimaryCta;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final primary = message.ctas.isNotEmpty ? message.ctas.first : null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.renderTypeRaw,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
            if (message.title != null && message.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message.title!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child:
                    Text(message.body!, style: const TextStyle(fontSize: 13)),
              ),
            if (primary != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onPrimaryCta == null
                      ? null
                      : () => onPrimaryCta!(primary),
                  child: Text(primary.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
