/// Render type for an in-app message (matches backend `render_type`).
enum InAppRenderType {
  modal,
  banner,
  inline,
  inboxCard,
  unknown;

  static InAppRenderType fromString(String? raw) {
    switch (raw) {
      case 'modal':
        return InAppRenderType.modal;
      case 'banner':
        return InAppRenderType.banner;
      case 'inline':
        return InAppRenderType.inline;
      case 'inbox_card':
        return InAppRenderType.inboxCard;
      default:
        return InAppRenderType.unknown;
    }
  }

  String get rawValue {
    switch (this) {
      case InAppRenderType.modal:
        return 'modal';
      case InAppRenderType.banner:
        return 'banner';
      case InAppRenderType.inline:
        return 'inline';
      case InAppRenderType.inboxCard:
        return 'inbox_card';
      case InAppRenderType.unknown:
        return 'unknown';
    }
  }
}

/// Action performed when a CTA is tapped.
enum InAppCtaAction {
  deepLink,
  dismiss,
  custom,
  unknown;

  static InAppCtaAction fromString(String? raw) {
    switch (raw) {
      case 'deep_link':
        return InAppCtaAction.deepLink;
      case 'dismiss':
        return InAppCtaAction.dismiss;
      case 'custom':
        return InAppCtaAction.custom;
      default:
        return InAppCtaAction.unknown;
    }
  }
}

/// A call-to-action button on an in-app message.
class InAppCta {
  final String id;
  final String label;
  final InAppCtaAction action;
  final String? value;

  const InAppCta({
    required this.id,
    required this.label,
    required this.action,
    this.value,
  });

  factory InAppCta.fromJson(Map<String, dynamic> json) {
    return InAppCta(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      action: InAppCtaAction.fromString(json['action'] as String?),
      value: json['value'] as String?,
    );
  }
}

/// Persistence rules for an in-app message (max impressions, intervals, etc.).
class InAppPersistence {
  /// 'one_time' or 'persistent_until_dismissed'.
  final String mode;
  final int? maxImpressionsTotal;
  final int? minIntervalSeconds;

  const InAppPersistence({
    required this.mode,
    this.maxImpressionsTotal,
    this.minIntervalSeconds,
  });

  factory InAppPersistence.fromJson(Map<String, dynamic> json) {
    return InAppPersistence(
      mode: (json['mode'] as String?) ?? 'one_time',
      maxImpressionsTotal: (json['max_impressions_total'] as num?)?.toInt(),
      minIntervalSeconds: (json['min_interval_seconds'] as num?)?.toInt(),
    );
  }
}

/// A message returned by the in-app sync endpoint.
class InAppMessage {
  final String deliveryId;
  final String messageId;
  final InAppRenderType renderType;
  final int priority;
  final String? title;
  final String? body;
  final String? imageUrl;
  final List<InAppCta> ctas;
  final DateTime? expiresAt;
  final InAppPersistence? persistence;

  const InAppMessage({
    required this.deliveryId,
    required this.messageId,
    required this.renderType,
    required this.priority,
    required this.ctas,
    this.title,
    this.body,
    this.imageUrl,
    this.expiresAt,
    this.persistence,
  });

  /// Raw render type string as returned by the backend (e.g. `inbox_card`).
  String get renderTypeRaw => renderType.rawValue;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(exp);
  }

  factory InAppMessage.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as Map<String, dynamic>?) ?? {};
    final rawCtas = (json['ctas'] as List?) ?? const [];
    final rawPersistence = json['persistence'];
    return InAppMessage(
      deliveryId: json['delivery_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      renderType: InAppRenderType.fromString(json['render_type'] as String?),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      title: content['title'] as String?,
      body: content['body'] as String?,
      imageUrl: content['image_url'] as String?,
      ctas: rawCtas
          .map((item) => InAppCta.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      persistence: rawPersistence is Map
          ? InAppPersistence.fromJson(rawPersistence.cast<String, dynamic>())
          : null,
    );
  }
}
