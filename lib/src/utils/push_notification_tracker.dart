import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';

/// Handles sending push notification tracking metrics to the CDP backend.
class PushNotificationTracker {
  static const _baseUrl = 'https://api.opencdp.io/v1/metrics';

  /// Sends a push notification metric (delivered/opened) to the CDP backend.
  static Future<void> sendMetric(
    String apiKey,
    MetricEvent event,
    String deliveryId,
  ) async {
    final endpoint = '$_baseUrl/push/${event.name}';
    final body = {
      'delivery_id': deliveryId,
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          debugPrint('[CDP] Push metric sent successfully: ${event.name}');
        }
      } else {
        debugPrint(
          '[CDP] Failed to send ${event.name} metric '
          '(status: ${response.statusCode}) => ${response.body}',
        );
      }
    } catch (e, st) {
      debugPrint('[CDP] Error sending push metric: $e\n$st');
    }
  }
}
