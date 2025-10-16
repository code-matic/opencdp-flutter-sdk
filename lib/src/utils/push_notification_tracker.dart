import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';

/// Handles sending push notification tracking metrics to the CDP backend.
/// This is designed to be lightweight and usable in background contexts.
class PushNotificationTracker {
  // URL for push notification metrics
  static const _url =
      '${CDPEndpoints.baseUrl}${CDPEndpoints.notificationMetrics}';

  // Maximum number of retry attempts
  static const _maxRetries = 3;

  // Base delay for exponential backoff (in milliseconds)
  static const _baseRetryDelayMs = 1000;

  /// HTTP client for making requests - static to avoid creating multiple instances
  /// Null by default and created on demand to minimize memory usage in background contexts
  static http.Client? _httpClient;

  /// Get or create the HTTP client
  static http.Client _getClient() {
    _httpClient ??= http.Client();
    return _httpClient!;
  }

  /// Close the HTTP client if it exists
  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }

  /// Sends a push notification metric (delivered/opened) to the CDP backend.
  /// Includes retry logic with exponential backoff for better reliability.
  ///
  /// This method is designed to work in background contexts where the main
  /// SDK may not be initialized.
  static Future<bool> sendMetric(
    String apiKey,
    MetricEvent event,
    String deliveryId,
  ) async {
    final body = {'notificationId': deliveryId, 'event': event.name};
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        // Use a new client for each attempt in case of connection issues
        final client = _getClient();

        final response = await client.post(
          Uri.parse(_url),
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
          return true;
        } else {
          if (retryCount == _maxRetries) {
            debugPrint(
              '[CDP] Failed to send ${event.name} metric after $_maxRetries retries '
              '(status: ${response.statusCode}) => ${response.body}',
            );
            return false;
          }
        }
      } catch (e, st) {
        if (retryCount == _maxRetries) {
          debugPrint(
              '[CDP] Error sending push metric after $_maxRetries retries: $e\n$st');
          return false;
        }
      }

      // Calculate exponential backoff delay with jitter
      final delay = _baseRetryDelayMs * pow(2, retryCount) +
          Random().nextInt(_baseRetryDelayMs);
      await Future.delayed(Duration(milliseconds: delay.toInt()));
      retryCount++;
    }

    return false;
  }

  /// Sends a metric and doesn't wait for the result
  /// Useful for fire-and-forget scenarios in notification service extensions
  static void sendMetricAndForget(
    String apiKey,
    MetricEvent event,
    String deliveryId,
  ) {
    // Don't await - just fire the request and move on
    // Important for background tasks with limited execution time
    sendMetric(apiKey, event, deliveryId);
  }
}
