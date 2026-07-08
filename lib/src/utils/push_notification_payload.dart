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

/// Helpers for push notification v2 payloads (`custom_data`, `actions`, `image_url`).
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

  /// Normalizes an image URL string, prepending `https://` when no scheme is set.
  static String normalizeImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  /// Parses `data['image_url']` when the backend sends a rich push image URL.
  ///
  /// Returns `null` if missing or blank.
  static String? parseImageUrl(Map<String, dynamic> data) {
    final raw = data['image_url'];
    if (raw == null) return null;
    final url = raw.toString().trim();
    return url.isEmpty ? null : normalizeImageUrl(url);
  }

  /// Resolves a push image URL from CDP `data.image_url` and common FCM fields.
  ///
  /// Checks, in order: `data.image_url`, `data.image`, `data.gcm.notification.image`,
  /// [androidNotificationImageUrl] (`notification.android.image`), and
  /// [appleNotificationImageUrl].
  static String? resolveImageUrl(
    Map<String, dynamic> data, {
    String? androidNotificationImageUrl,
    String? appleNotificationImageUrl,
  }) {
    final fromCdp = parseImageUrl(data);
    if (fromCdp != null) return fromCdp;

    for (final key in const [
      'image',
      'gcm.notification.image',
      'notification_image',
    ]) {
      final raw = data[key];
      if (raw == null) continue;
      final url = raw.toString().trim();
      if (url.isNotEmpty) return normalizeImageUrl(url);
    }

    final android = androidNotificationImageUrl?.trim();
    if (android != null && android.isNotEmpty) {
      return normalizeImageUrl(android);
    }

    final apple = appleNotificationImageUrl?.trim();
    if (apple != null && apple.isNotEmpty) {
      return normalizeImageUrl(apple);
    }

    return null;
  }

  /// Writes resolved `image_url` into [data] when found via [resolveImageUrl].
  static void enrichDataWithImageUrl(
    Map<String, dynamic> data, {
    String? androidNotificationImageUrl,
    String? appleNotificationImageUrl,
  }) {
    final resolved = resolveImageUrl(
      data,
      androidNotificationImageUrl: androidNotificationImageUrl,
      appleNotificationImageUrl: appleNotificationImageUrl,
    );
    if (resolved != null) {
      data.putIfAbsent('image_url', () => resolved);
    }
  }
}
