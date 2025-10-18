import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';

/// Handles sending push notification tracking metrics to the CDP backend.
/// This is designed to be lightweight and usable in background contexts.
class PushNotificationTracker {
  // URL for push notification metrics
  static const _url =
      'https://simple-push.onrender.com/${CDPEndpoints.notificationMetrics}';

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
    String deliveryMessageId, {
    String? personId,
    String deliverySendContext = "transactional",
    String deliverySendContextId = "",
    bool isBackground = false,
    String? appGroup,
  }) async {
    // If personId is not provided and we're in background mode, try to get from native storage
    String? userId = personId;
    if (userId == null && isBackground) {
      // For iOS, we need the app group
      // For Android, app group is not needed
      userId = await NativeBridge.getUserIdFromNative(
        appGroup: appGroup, // Will be used on iOS, ignored on Android
      );
    }

    // If we still don't have a userId, check if it's in the deliveryMessageId (some systems embed it)
    if (userId == null && deliveryMessageId.contains(':')) {
      final parts = deliveryMessageId.split(':');
      if (parts.length > 1) {
        userId = parts[0];
        debugPrint(
            '[CDP] Extracted user ID from message ID: ${safeSubstring(userId, 5)}');
      }
    }

    // If we still don't have a userId, we can't send the metric
    if (userId == null) {
      debugPrint('[CDP] Cannot send push metric: No user ID available');
      return false;
    }

    // Get current timestamp in ISO8601 format with UTC timezone
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final body = {
      'message_id': deliveryMessageId,
      'person_id': userId,
      'send_context': deliverySendContext,
      'send_context_id': deliverySendContextId,
      'status': _mapEventToStatus(event),
      'ts': timestamp,
    };
    debugPrint('[CDP] Sending push metric: ${jsonEncode(body)}...');

    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        // Use a new client for each attempt in case of connection issues
        final client = _getClient();

        debugPrint(
            '[CDP] Sending push metric $retryCount: ${jsonEncode(body)}...');

        final response = await client.post(
          Uri.parse(_url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': apiKey,
          },
          body: jsonEncode(body),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint(
                '[CDP] Push metric sent successfully: ${_mapEventToStatus(event)}');
          }
          return true;
        } else {
          if (retryCount == _maxRetries) {
            debugPrint(
              '[CDP] Failed to send ${_mapEventToStatus(event)} metric after $_maxRetries retries '
              '(status: ${response.statusCode})Request body:{jsonEncode(body)} Response body:=> ${response.body}',
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
  /// On iOS, requires appGroup for background operations
  /// On Android, appGroup is not needed
  static void sendMetricAndForget(
    String apiKey,
    MetricEvent event,
    String deliveryMessageId, {
    String? personId,
    String deliverySendContext = "transactional",
    String deliverySendContextId = "",
    bool isBackground = false,
    String? appGroup,
  }) {
    // Don't await - just fire the request and move on
    // Important for background tasks with limited execution time
    sendMetric(
      apiKey,
      event,
      deliveryMessageId,
      personId: personId,
      deliverySendContext: deliverySendContext,
      deliverySendContextId: deliverySendContextId,
      isBackground: isBackground,
      appGroup: appGroup,
    );
  }

  /// Maps a MetricEvent to the corresponding status string for the API
  static String _mapEventToStatus(MetricEvent event) {
    switch (event) {
      case MetricEvent.delivered:
        return 'delivered';
      case MetricEvent.opened:
        return 'opened';
      case MetricEvent.converted:
        return 'converted';
      case MetricEvent.failed:
        return 'failed';
      default:
        return 'unknown';
    }
  }

  /// Helper to safely get a substring prefix of a string
  static String safeSubstring(String input, int maxLength) {
    if (input.isEmpty) return '';
    final length = min(maxLength, input.length);
    return '${input.substring(0, length)}${length < input.length ? '...' : ''}';
  }
}
