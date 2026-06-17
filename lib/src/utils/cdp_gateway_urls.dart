import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';

/// Helpers for primary + backup data-gateway base URLs.
class CdpGatewayUrls {
  CdpGatewayUrls._();

  static const Duration defaultRequestTimeout = Duration(seconds: 30);
  static const Duration minRequestTimeout = Duration(seconds: 5);
  static const Duration maxRequestTimeout = Duration(seconds: 120);

  static const List<String> defaultFallbackBaseUrls = [
    CDPEndpoints.backupBaseUrlXyz,
    CDPEndpoints.backupBaseUrlCom,
  ];

  /// Clamps [value] to [minRequestTimeout]..[maxRequestTimeout].
  static Duration clampRequestTimeout(Duration value) {
    if (value < minRequestTimeout) return minRequestTimeout;
    if (value > maxRequestTimeout) return maxRequestTimeout;
    return value;
  }

  /// Trims whitespace and removes a trailing slash.
  static String normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Ordered gateway roots: primary first, then fallbacks (deduplicated).
  static List<String> resolveAllBaseUrls({
    String? primaryOverride,
    List<String>? fallbackOverrides,
  }) {
    final primary = normalizeBaseUrl(
      (primaryOverride != null && primaryOverride.trim().isNotEmpty)
          ? primaryOverride
          : CDPEndpoints.baseUrl,
    );
    final fallbacks = fallbackOverrides ?? defaultFallbackBaseUrls;
    final seen = <String>{};
    final ordered = <String>[];

    void add(String url) {
      final normalized = normalizeBaseUrl(url);
      if (normalized.isEmpty || seen.contains(normalized)) return;
      seen.add(normalized);
      ordered.add(normalized);
    }

    add(primary);
    for (final fallback in fallbacks) {
      add(fallback);
    }
    return ordered;
  }
}
