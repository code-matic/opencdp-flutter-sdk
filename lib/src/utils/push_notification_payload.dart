import 'dart:convert';

/// A push action button delivered in the FCM `data.actions` JSON string.
///
/// See [OpenCDPPushPayload.parseActions].
class CDPPushAction {
  const CDPPushAction({
    required this.actionId,
    required this.label,
    this.link,
    this.icon,
  });

  final String actionId;
  final String label;
  final String? link;
  final String? icon;
}

/// Helpers for push notification v2 payloads (`custom_data`, `actions`).
class OpenCDPPushPayload {
  OpenCDPPushPayload._();

  /// Parses `data['custom_data']` when the backend sends it as a JSON object string.
  ///
  /// Returns `null` if missing, empty, or invalid JSON.
  static Map<String, dynamic>? parseCustomData(Map<String, dynamic> data) {
    final raw = data['custom_data'];
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Parses `data['actions']` JSON string into at most [maxActions] items (default 3).
  ///
  /// Invalid entries are skipped. Malformed JSON returns an empty list.
  static List<CDPPushAction> parseActions(
    Map<String, dynamic> data, {
    int maxActions = 3,
  }) {
    final raw = data['actions'];
    if (raw == null) return const [];

    dynamic decoded;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const [];
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        return const [];
      }
    } else if (raw is List) {
      decoded = raw;
    } else {
      return const [];
    }

    if (decoded is! List) return const [];

    final out = <CDPPushAction>[];
    for (final item in decoded) {
      if (out.length >= maxActions) break;
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final actionId = (m['action_id'] ?? m['actionId'])?.toString().trim();
      final label = m['label']?.toString().trim();
      if (actionId == null ||
          actionId.isEmpty ||
          label == null ||
          label.isEmpty) {
        continue;
      }
      final link = m['link']?.toString();
      final icon = m['icon']?.toString();
      out.add(CDPPushAction(
        actionId: actionId,
        label: label,
        link: link != null && link.isEmpty ? null : link,
        icon: icon != null && icon.isEmpty ? null : icon,
      ));
    }
    return out;
  }
}
