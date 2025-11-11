import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Note: The original code depended on `request_queue.dart`. For completeness,
// plausible implementations of `RequestQueue` and `QueuedRequest` are included here.

/// Represents a single API request that has been queued for a future retry.
class QueuedRequest {
  /// The API endpoint for the request (e.g., '/v1/identify').
  final String endpoint;

  /// The JSON body of the request.
  final Map<String, dynamic> body;

  /// An optional unique identifier for the request.
  final String? identifier;

  /// The number of times this request has been attempted.
  /// This is used to calculate the exponential backoff delay.
  int retryCount;

  /// The timestamp when the request was first created.
  final DateTime createdAt;

  QueuedRequest({
    required this.endpoint,
    required this.body,
    this.identifier,
    this.retryCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a `QueuedRequest` instance from a JSON map.
  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      endpoint: json['endpoint'] as String,
      body: jsonDecode(json['body'] as String) as Map<String, dynamic>,
      identifier: json['identifier'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts this `QueuedRequest` instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'body': jsonEncode(body),
      'identifier': identifier,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Manages a list of [QueuedRequest] objects.
class RequestQueue {
  final List<QueuedRequest> _requests = [];

  /// Returns a copy of the pending requests.
  List<QueuedRequest> get pendingRequests => List.unmodifiable(_requests);

  /// Returns true if there are requests in the queue.
  bool get hasRequests => _requests.isNotEmpty;

  /// Adds a request to the queue.
  void addRequest(QueuedRequest request) {
    _requests.add(request);
  }

  /// Removes a request from the queue.
  void removeRequest(QueuedRequest request) {
    _requests.remove(request);
  }

  /// Clears all requests from the queue.
  void clear() {
    _requests.clear();
  }

  /// Populates the queue from a JSON string.
  void fromJson(String jsonString) {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _requests.clear();
      _requests.addAll(jsonList
          .map((item) => QueuedRequest.fromJson(item as Map<String, dynamic>)));
    } catch (_) {
      // If decoding fails, start with a fresh queue.
      _requests.clear();
    }
  }

  /// Converts the entire queue to a JSON string.
  String toJson() {
    return jsonEncode(_requests.map((req) => req.toJson()).toList());
  }
}

/// A robust HTTP client for CDP API calls that handles offline scenarios
/// by queuing failed requests and retrying them with exponential backoff.
class CDPHttpClient {
  /// The underlying `http` client used for making requests.
  final http.Client _client;

  /// The base URL for the CDP API (e.g., 'https://api.customer.io').
  final String baseUrl;

  /// The API key used for the 'Authorization' header.
  final String apiKey;

  /// If true, detailed logs will be printed to the console.
  final bool debug;

  /// The queue for managing failed requests that need to be retried.
  final RequestQueue _requestQueue = RequestQueue();

  /// A flag to prevent concurrent processing of the request queue.
  bool _isProcessingQueue = false;

  /// The key used to store the request queue in SharedPreferences.
  static const String _queueKey = 'cdp_request_queue';

  /// The maximum number of retries for a single request before it is discarded.
  static const int _maxRetries = 5;

  /// Private constructor. Use the `CDPHttpClient.create()` factory to instantiate.
  CDPHttpClient._({
    required this.baseUrl,
    required this.apiKey,
    this.debug = false,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Creates and initializes a new CDP HTTP client.
  ///
  /// This factory method handles the asynchronous loading of the persisted
  /// request queue, ensuring the client is ready for use upon creation.
  ///
  /// [baseUrl] is the base URL for the CDP API.
  /// [apiKey] is the API key used for authentication.
  /// [debug] enables debug logging if true.
  /// [client] is an optional HTTP client to use. If not provided, a new one is created.
  static Future<CDPHttpClient> create({
    required String baseUrl,
    required String apiKey,
    bool debug = false,
    http.Client? client,
  }) async {
    final instance = CDPHttpClient._(
      baseUrl: baseUrl,
      apiKey: apiKey,
      debug: debug,
      client: client,
    );
    // Await the loading of the queue before the client is used.
    await instance._loadQueue();
    return instance;
  }

  /// Loads the request queue from persistent storage.
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson != null) {
        _requestQueue.fromJson(queueJson);
        if (debug) {
          debugPrint(
              '[CDP] Loaded ${_requestQueue.pendingRequests.length} pending requests from storage.');
        }
      }
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error loading request queue: $e');
      }
    }
  }

  /// Saves the current request queue to persistent storage.
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

  /// Makes a POST request to the CDP API.
  ///
  /// If the request is successful, it returns the decoded JSON response.
  /// If the request fails due to a network error or a non-200 status code,
  /// it is added to a persistent queue for a later retry.
  ///
  /// [endpoint] is the API endpoint to call (e.g., '/v1/identify').
  /// [body] is the request body as a map, which will be JSON encoded.
  /// [identifier] is an optional identifier for the request.
  ///
  /// Throws a [CDPException] if the request fails.
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

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Queue the failed request and throw an exception.
        final failedRequest = QueuedRequest(
          endpoint: endpoint,
          body: body,
          identifier: identifier,
        );
        _requestQueue.addRequest(failedRequest);
        await _saveQueue();

        if (debug) {
          debugPrint(
              '[CDP] Failed request to $endpoint queued for retry. Status: ${response.statusCode}, Body: ${response.body}');
        }
        throw CDPException(
          'API request failed: ${response.body}',
          response.statusCode,
        );
      }

      if (debug) {
        debugPrint('[CDP] Successfully sent request to $endpoint.');
        debugPrint('[CDP] Response: ${response.body}');
      }

      // If the request was successful, try to process any pending requests
      // in the background. Do not await this.
      // ignore: unawaited_futures
      _processPendingRequests();

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error making request to $endpoint: $e');
      }
      // Re-throw any exception as a CDPException to standardize error handling.
      throw CDPException('Error making request to $endpoint: $e');
    }
  }

  /// Processes pending requests from the queue with exponential backoff.
  Future<void> _processPendingRequests() async {
    // Use a lock to prevent multiple concurrent processing runs.
    if (_isProcessingQueue || !_requestQueue.hasRequests) return;

    _isProcessingQueue = true;
    if (debug) {
      debugPrint(
          '[CDP] Starting to process ${_requestQueue.pendingRequests.length} queued requests.');
    }

    try {
      final requestsToProcess = List.of(_requestQueue.pendingRequests);
      for (final request in requestsToProcess) {
        try {
          // Implement exponential backoff: delay = 2^retryCount seconds.
          final delayInSeconds = pow(2, request.retryCount);
          await Future.delayed(Duration(seconds: delayInSeconds.toInt()));

          final response = await _client.post(
            Uri.parse('$baseUrl${request.endpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': apiKey,
            },
            body: jsonEncode(request.body),
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            _requestQueue.removeRequest(request);
            if (debug) {
              debugPrint(
                  '[CDP] Successfully processed queued request to ${request.endpoint}.');
            }
          } else {
            // If it still fails, increment the retry count for the next attempt.
            request.retryCount++;
          }
        } catch (e) {
          // If a network error occurs, increment retry count.
          request.retryCount++;
          if (debug) {
            debugPrint(
                '[CDP] Error processing queued request to ${request.endpoint}: $e. Retry count: ${request.retryCount}');
          }
        }

        // Discard requests that have exceeded the max retry limit.
        if (request.retryCount > _maxRetries) {
          _requestQueue.removeRequest(request);
          if (debug) {
            debugPrint(
                '[CDP] Discarding request to ${request.endpoint} after reaching max retries.');
          }
        }
      }
    } finally {
      // ALWAYS release the lock, even if an error occurs.
      _isProcessingQueue = false;
    }

    // Persist changes to the queue (removed/updated requests).
    await _saveQueue();
  }

  /// Clears identity-specific data.
  ///
  /// This method attempts to send any pending requests one final time,
  /// then clears the in-memory queue and removes it from persistent storage.
  Future<void> clearIdentity() async {
    try {
      // Try one last time to process any pending requests.
      await _processPendingRequests();

      // Clear the in-memory queue.
      _requestQueue.clear();

      // Clear from persistent storage.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);

      if (debug) {
        debugPrint('[CDP] Cleared identity and flushed request queue.');
      }
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error clearing identity: $e');
      }
    }
  }

  /// Closes the underlying HTTP client.
  ///
  /// This should be called when the client is no longer needed to free up resources.
  /// For reinitialization, this method ensures all resources are properly released.
  void dispose() {
    try {
      // 1. Cancel any ongoing processing
      _isProcessingQueue = false;

      // 2. Close the HTTP client to release network resources
      _client.close();

      // Note: We don't clear the queue here as that would lose pending requests
      // If you need to clear the queue, call clearIdentity() before dispose()

      if (debug) {
        debugPrint('[CDP] HTTP client disposed');
      }
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error disposing HTTP client: $e');
      }
    }
  }
}

/// Custom exception for CDP API errors.
class CDPException implements Exception {
  final String message;
  final int? statusCode;

  CDPException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CDPException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
