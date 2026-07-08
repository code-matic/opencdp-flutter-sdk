import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/utils/cdp_gateway_urls.dart';

/// Handles sending push notification tracking metrics to the CDP backend.
/// This is designed to be lightweight and usable in background contexts.
class PushNotificationTracker {
  /// Resolves the delivery URL for a gateway [baseUrl] root.
  static String deliveryPushUrl(String baseUrl) {
    final t = baseUrl.trim();
    if (t.isEmpty) {
      return '${CDPEndpoints.baseUrl}${CDPEndpoints.notificationMetrics}';
    }
    final root = t.endsWith('/') ? t.substring(0, t.length - 1) : t;
    return '$root${CDPEndpoints.notificationMetrics}';
  }

  static const _maxRetries = 3;
  static const _baseRetryDelayMs = 1000;

  static http.Client? _httpClient;

  static http.Client _getClient() {
    _httpClient ??= http.Client();
    return _httpClient!;
  }

  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }

  /// Tries each gateway host in [baseUrls] (primary first) until one returns 2xx.
  static Future<http.Response?> _postMetricWithFailover(
    List<String> baseUrls,
    String apiKey,
    Map<String, dynamic> body,
    Duration requestTimeout,
  ) async {
    final client = _getClient();
    http.Response? lastResponse;
    for (final root in baseUrls) {
      try {
        final response = await client
            .post(
              Uri.parse(deliveryPushUrl(root)),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': apiKey,
              },
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        lastResponse = response;
        if (kDebugMode) {
          debugPrint(
            '[CDP] Push metric non-2xx on $root (${response.statusCode}) '
            'url=${deliveryPushUrl(root)} body=${response.body}',
          );
        }
      } catch (e) {
        debugPrint('[CDP] Push metric failed on $root: $e');
      }
    }
    return lastResponse;
  }

  /// Sends a push notification metric to the data-gateway `message/delivery/push` API.
  ///
  /// Tries [baseUrls] in order on each attempt, then applies exponential backoff
  /// when all hosts fail.
  static Future<bool> sendMetric(
    String apiKey,
    List<String> baseUrls,
    MetricEvent event,
    String deliveryMessageId, {
    String? personId,
    String deliverySendContext = "transactional",
    String deliverySendContextId = "",
    bool isBackground = false,
    String? appGroup,
    String? actionId,
    Duration requestTimeout = CdpGatewayUrls.defaultRequestTimeout,
  }) async {
    final resolvedUrls = baseUrls.isEmpty
        ? CdpGatewayUrls.resolveAllBaseUrls()
        : baseUrls;
    final timeout = CdpGatewayUrls.clampRequestTimeout(requestTimeout);

    String? userId = personId;
    if (userId == null && isBackground) {
      userId = await NativeBridge.getUserIdFromNative(
        appGroup: appGroup,
      );
    }

    if (userId == null && deliveryMessageId.contains(':')) {
      final parts = deliveryMessageId.split(':');
      if (parts.length > 1) {
        userId = parts[0];
        debugPrint(
            '[CDP] Extracted user ID from message ID: ${safeSubstring(userId, 5)}');
      }
    }

    if (userId == null) {
      debugPrint('[CDP] Cannot send push metric: No user ID available');
      return false;
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();

    final body = <String, dynamic>{
      'message_id': deliveryMessageId,
      'person_id': userId,
      'send_context': deliverySendContext,
      'send_context_id': deliverySendContextId,
      'status': _mapEventToStatus(event),
      'ts': timestamp,
    };
    if (event == MetricEvent.actionClicked) {
      final trimmedAction = actionId?.trim();
      if (trimmedAction != null && trimmedAction.isNotEmpty) {
        body['props'] = <String, dynamic>{'action_id': trimmedAction};
      } else {
        debugPrint(
          '[CDP] Warning: push metric status is clicked but action_id is empty in props.',
        );
      }
    }
    debugPrint('[CDP] Sending push metric: ${jsonEncode(body)}...');

    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        debugPrint(
            '[CDP] Sending push metric attempt $retryCount: ${jsonEncode(body)}...');

        final response = await _postMetricWithFailover(
          resolvedUrls,
          apiKey,
          body,
          timeout,
        );

        if (response != null &&
            response.statusCode >= 200 &&
            response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint(
              '[CDP] Push metric sent successfully: ${_mapEventToStatus(event)} '
              'status=${response.statusCode} body=${response.body}',
            );
          }
          return true;
        }

        if (retryCount == _maxRetries) {
          final status = response?.statusCode;
          debugPrint(
            '[CDP] Failed to send ${_mapEventToStatus(event)} metric after $_maxRetries retries '
            '(status: $status) Request body: ${jsonEncode(body)} Response body: ${response?.body}',
          );
          return false;
        }
      } catch (e, st) {
        if (retryCount == _maxRetries) {
          debugPrint(
              '[CDP] Error sending push metric after $_maxRetries retries: $e\n$st');
          return false;
        }
      }

      final delay = _baseRetryDelayMs * pow(2, retryCount) +
          Random().nextInt(_baseRetryDelayMs);
      await Future.delayed(Duration(milliseconds: delay.toInt()));
      retryCount++;
    }

    return false;
  }

  static void sendMetricAndForget(
    String apiKey,
    List<String> baseUrls,
    MetricEvent event,
    String deliveryMessageId, {
    String? personId,
    String deliverySendContext = "transactional",
    String deliverySendContextId = "",
    bool isBackground = false,
    String? appGroup,
    String? actionId,
    Duration requestTimeout = CdpGatewayUrls.defaultRequestTimeout,
  }) {
    sendMetric(
      apiKey,
      baseUrls,
      event,
      deliveryMessageId,
      personId: personId,
      deliverySendContext: deliverySendContext,
      deliverySendContextId: deliverySendContextId,
      isBackground: isBackground,
      appGroup: appGroup,
      actionId: actionId,
      requestTimeout: requestTimeout,
    );
  }

  static String _mapEventToStatus(MetricEvent event) {
    switch (event) {
      case MetricEvent.delivered:
        return 'delivered';
      case MetricEvent.opened:
        return 'opened';
      case MetricEvent.actionClicked:
        return 'clicked';
      case MetricEvent.converted:
        return 'converted';
      case MetricEvent.failed:
        return 'failed';
    }
  }

  static String safeSubstring(String input, int maxLength) {
    if (input.isEmpty) return '';
    final length = min(maxLength, input.length);
    return '${input.substring(0, length)}${length < input.length ? '...' : ''}';
  }
}
