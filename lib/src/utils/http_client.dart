import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meta/meta.dart';
import 'request_queue.dart';

/// HTTP client wrapper for CDP API calls
class CDPHttpClient {
  final http.Client _client;
  final String baseUrl;
  final String apiKey;
  final bool debug;
  final RequestQueue _requestQueue = RequestQueue();
  static const String _queueKey = 'cdp_request_queue';

  /// Creates a new CDP HTTP client.
  ///
  /// [baseUrl] is the base URL for the CDP API.
  /// [apiKey] is the API key used for authentication.
  /// [debug] enables debug logging if true.
  /// [client] is an optional HTTP client to use. If not provided, a new one is created.
  CDPHttpClient({
    required this.baseUrl,
    required this.apiKey,
    this.debug = false,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    _loadQueue();
  }

  /// Load the request queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson != null) {
        _requestQueue.fromJson(queueJson);
        if (debug) {
          debugPrint(
              '[CDP] Loaded ${_requestQueue.pendingRequests.length} pending requests');
        }
      }
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error loading request queue: $e');
      }
    }
  }

  /// Save the request queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, _requestQueue.toJson());
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error saving request queue: $e');
      }
    }
  }

  /// Make a POST request to the CDP API
  ///
  /// [endpoint] is the API endpoint to call.
  /// [body] is the request body as a map.
  /// [identifier] is an optional identifier for the request.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? identifier,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': apiKey,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        // Queue the failed request
        final failedRequest = QueuedRequest(
          endpoint: endpoint,
          body: body,
          identifier: identifier,
        );
        _requestQueue.addRequest(failedRequest);
        await _saveQueue();

        throw CDPException(
          'Failed to make request to $endpoint: ${response.body}',
          response.statusCode,
        );
      }

      if (debug) {
        final action = endpoint.split('/').last;
        final id = identifier ?? 'unknown';
        debugPrint('[CDP] $action');
        debugPrint('[CDP] Endpoint: $endpoint');
        debugPrint('[CDP] Status Code: ${response.statusCode}');
        debugPrint('[CDP] Response: ${response.body}');
      }

      // If request was successful, try to process any pending requests
      // Don't await as this is a background operation
      // ignore: unawaited_futures
      _processPendingRequests();

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error making request to $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Process any pending requests in the queue
  Future<void> _processPendingRequests() async {
    if (!_requestQueue.hasRequests) return;

    final requests = List.of(_requestQueue.pendingRequests);
    for (final request in requests) {
      try {
        final response = await _client.post(
          Uri.parse('$baseUrl${request.endpoint}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': apiKey,
          },
          body: jsonEncode(request.body),
        );

        if (response.statusCode == 200) {
          _requestQueue.removeRequest(request);
          if (debug) {
            debugPrint(
                '[CDP] Successfully processed queued request to ${request.endpoint}');
          }
        }
      } catch (e) {
        if (debug) {
          debugPrint(
              '[CDP] Error processing queued request to ${request.endpoint}: $e');
        }
        // Keep the request in the queue for future retry
        continue;
      }
    }

    await _saveQueue();
  }

  /// Clear identity and flush all pending requests
  ///
  /// This method:
  /// - Attempts to process any pending requests one final time
  /// - Clears the request queue
  /// - Removes the queue from persistent storage
  Future<void> clearIdentity() async {
    try {
      // First try to process any pending requests one final time
      await _processPendingRequests();

      // Then clear the in-memory queue
      _requestQueue.clear();

      // Finally clear the persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);

      if (debug) {
        debugPrint('[CDP] Cleared identity and flushed request queue');
      }
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error clearing identity: $e');
      }
      rethrow;
    }
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}

/// Custom exception for CDP API errors
class CDPException implements Exception {
  final String message;
  final int? statusCode;

  CDPException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CDPException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
