import 'package:flutter/material.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';

/// Default modal dialog for [InAppRenderType.modal].
///
/// Pops with the tapped CTA id, or `null` when dismissed without a CTA.
class OpenCDPInAppModalDialog extends StatelessWidget {
  const OpenCDPInAppModalDialog({super.key, required this.message});

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

/// Top banner for [InAppRenderType.banner].
class OpenCDPInAppBanner extends StatelessWidget {
  const OpenCDPInAppBanner({
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
            Icon(Icons.notifications_active, color: Colors.blueGrey.shade700),
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

/// Default embeddable card for [InAppRenderType.inline] / inbox slots.
class OpenCDPInAppInlineCard extends StatelessWidget {
  const OpenCDPInAppInlineCard({
    super.key,
    required this.message,
    this.onCta,
    this.onDismiss,
  });

  final InAppMessage message;
  final VoidCallback? onCta;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = message.title?.trim();
    final body = message.body?.trim();
    final cta = message.primaryCta;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.campaign_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (body != null && body.isNotEmpty) ...[
                    if (title != null && title.isNotEmpty)
                      const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodySmall),
                  ],
                  if (cta != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onCta,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(cta.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
