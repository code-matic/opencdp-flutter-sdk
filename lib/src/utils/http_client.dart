import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/utils/cdp_gateway_urls.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Result of trying all gateway hosts for one HTTP exchange.
@visibleForTesting
class CdpHttpFailoverResult {
  final http.Response? response;
  final Object? error;
  final String? lastBaseUrl;

  const CdpHttpFailoverResult({
    this.response,
    this.error,
    this.lastBaseUrl,
  });

  bool get succeeded {
    final r = response;
    return r != null && r.statusCode >= 200 && r.statusCode < 300;
  }
}

/// A robust HTTP client for CDP API calls that handles offline scenarios
/// by queuing failed requests and retrying them with exponential backoff.
class CDPHttpClient {
  /// The underlying `http` client used for making requests.
  final http.Client _client;

  /// Underlying `http.Client`, exposed so siblings (e.g. the realtime SSE
  /// client) can issue long-lived streaming requests with the same
  /// connection settings while preserving the queue/retry semantics here.
  http.Client get rawClient => _client;

  /// Ordered gateway base URLs (primary first, then backups).
  final List<String> baseUrls;

  /// Primary gateway base URL — first entry in [baseUrls].
  String get baseUrl => baseUrls.first;

  /// The API key used for the 'Authorization' header.
  final String apiKey;

  /// If true, detailed logs will be printed to the console.
  final bool debug;

  /// Per-request timeout for gateway POST/GET and stream connect headers.
  final Duration requestTimeout;

  /// The queue for managing failed requests that need to be retried.
  final RequestQueue _requestQueue = RequestQueue();

  /// A flag to prevent concurrent processing of the request queue.
  bool _isProcessingQueue = false;

  /// The key used to store the request queue in SharedPreferences.
  static const String _queueKey = 'cdp_request_queue';

  /// The maximum number of retries for a single request before it is discarded.
  static const int _maxRetries = 5;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  /// Private constructor. Use the `CDPHttpClient.create()` factory to instantiate.
  CDPHttpClient._({
    required this.baseUrls,
    required this.apiKey,
    this.debug = false,
    required this.requestTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Creates and initializes a new CDP HTTP client.
  ///
  /// Provide either [baseUrls] or [baseUrl] (with optional [fallbackBaseUrls]).
  /// Every new request tries hosts in order until one returns 2xx.
  static Future<CDPHttpClient> create({
    required String apiKey,
    String? baseUrl,
    List<String>? baseUrls,
    List<String>? fallbackBaseUrls,
    Duration requestTimeout = CdpGatewayUrls.defaultRequestTimeout,
    bool debug = false,
    http.Client? client,
  }) async {
    final resolvedUrls = baseUrls ??
        CdpGatewayUrls.resolveAllBaseUrls(
          primaryOverride: baseUrl,
          fallbackOverrides: fallbackBaseUrls,
        );
    if (resolvedUrls.isEmpty) {
      throw ArgumentError('At least one CDP base URL is required.');
    }

    final instance = CDPHttpClient._(
      baseUrls: resolvedUrls,
      apiKey: apiKey,
      debug: debug,
      requestTimeout: CdpGatewayUrls.clampRequestTimeout(requestTimeout),
      client: client,
    );
    await instance._loadQueue();
    if (instance._requestQueue.hasRequests) {
      // ignore: unawaited_futures
      instance._processPendingRequests();
    }
    return instance;
  }

  Map<String, String> get _authHeaders => {
        ..._jsonHeaders,
        'Authorization': apiKey,
      };

  /// Tries [baseUrls] in order for a POST until one returns 2xx.
  @visibleForTesting
  Future<CdpHttpFailoverResult> postWithFailover(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    http.Response? lastResponse;
    Object? lastError;
    String? lastBase;

    for (final root in baseUrls) {
      lastBase = root;
      try {
        final response = await _client
            .post(
              Uri.parse('$root$endpoint'),
              headers: _authHeaders,
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return CdpHttpFailoverResult(
            response: response,
            lastBaseUrl: root,
          );
        }
        lastResponse = response;
        if (debug) {
          debugPrint(
            '[CDP] POST $endpoint non-2xx on $root (${response.statusCode}), trying next host.',
          );
        }
      } catch (e) {
        lastError = e;
        if (debug) {
          debugPrint('[CDP] POST $endpoint failed on $root: $e');
        }
      }
    }

    return CdpHttpFailoverResult(
      response: lastResponse,
      error: lastError,
      lastBaseUrl: lastBase,
    );
  }

  /// Tries [baseUrls] in order for a GET until one returns 2xx.
  @visibleForTesting
  Future<CdpHttpFailoverResult> getWithFailover(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    http.Response? lastResponse;
    Object? lastError;
    String? lastBase;

    for (final root in baseUrls) {
      lastBase = root;
      try {
        final uri = Uri.parse('$root$endpoint').replace(
          queryParameters:
              query?.map((key, value) => MapEntry(key, '$value')),
        );
        final response = await _client
            .get(uri, headers: _authHeaders)
            .timeout(requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return CdpHttpFailoverResult(
            response: response,
            lastBaseUrl: root,
          );
        }
        lastResponse = response;
        if (debug) {
          debugPrint(
            '[CDP] GET $endpoint non-2xx on $root (${response.statusCode}), trying next host.',
          );
        }
      } catch (e) {
        lastError = e;
        if (debug) {
          debugPrint('[CDP] GET $endpoint failed on $root: $e');
        }
      }
    }

    return CdpHttpFailoverResult(
      response: lastResponse,
      error: lastError,
      lastBaseUrl: lastBase,
    );
  }

  /// Opens a streaming GET, trying [baseUrls] until connect returns 2xx headers.
  Future<http.StreamedResponse> sendGetStreamWithFailover({
    required String endpoint,
    required Map<String, String> headers,
    Map<String, String>? queryParameters,
  }) async {
    http.StreamedResponse? lastResponse;
    Object? lastError;

    for (final root in baseUrls) {
      try {
        final uri = Uri.parse('$root$endpoint').replace(
          queryParameters: queryParameters,
        );
        final request = http.Request('GET', uri);
        request.headers.addAll(headers);

        final response = await rawClient.send(request).timeout(requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastResponse = response;
        try {
          await response.stream.drain<void>();
        } catch (_) {/* ignore drain failures */}

        if (debug) {
          debugPrint(
            '[CDP] Stream GET $endpoint non-2xx on $root (${response.statusCode}), trying next host.',
          );
        }
      } catch (e) {
        lastError = e;
        if (debug) {
          debugPrint('[CDP] Stream GET $endpoint failed on $root: $e');
        }
      }
    }

    if (lastResponse != null) {
      return lastResponse;
    }
    throw CDPException(
      'Error opening stream GET to $endpoint: $lastError',
    );
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

  void _throwFromFailoverResult(CdpHttpFailoverResult result, String verb) {
    final response = result.response;
    if (response != null) {
      throw CDPException(
        'API request failed: ${response.body}',
        response.statusCode,
      );
    }
    throw CDPException('Error making $verb request: ${result.error}');
  }

  /// Makes a POST request to the CDP API.
  ///
  /// Tries primary then backup hosts. On failure across all hosts, queues for
  /// later retry and throws [CDPException].
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? identifier,
  }) async {
    try {
      final result = await postWithFailover(endpoint, body);

      if (!result.succeeded) {
        final failedRequest = QueuedRequest(
          endpoint: endpoint,
          body: body,
          identifier: identifier,
        );
        _requestQueue.addRequest(failedRequest);
        await _saveQueue();

        if (debug) {
          final status = result.response?.statusCode;
          debugPrint(
            '[CDP] Failed POST $endpoint on all hosts (last status: $status). Queued for retry.',
          );
        }
        _throwFromFailoverResult(result, 'POST to $endpoint');
      }

      final response = result.response!;
      if (debug) {
        debugPrint(
          '[CDP] Successfully sent POST to $endpoint via ${result.lastBaseUrl}.',
        );
        debugPrint('[CDP] Response: ${response.body}');
      }

      // ignore: unawaited_futures
      _processPendingRequests();

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on CDPException {
      rethrow;
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error making POST request to $endpoint: $e');
      }
      throw CDPException('Error making request to $endpoint: $e');
    }
  }

  /// Makes a GET request to the CDP API.
  ///
  /// Tries primary then backup hosts. Throws [CDPException] if all fail.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final result = await getWithFailover(endpoint, query: query);

      if (!result.succeeded) {
        if (debug) {
          final status = result.response?.statusCode;
          debugPrint(
            '[CDP] Failed GET $endpoint on all hosts. Last status: $status',
          );
        }
        _throwFromFailoverResult(result, 'GET to $endpoint');
      }

      final response = result.response!;
      if (debug) {
        debugPrint(
          '[CDP] Successfully sent GET to $endpoint via ${result.lastBaseUrl}.',
        );
        debugPrint('[CDP] Response: ${response.body}');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on CDPException {
      rethrow;
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error making GET request to $endpoint: $e');
      }
      throw CDPException('Error making GET request to $endpoint: $e');
    }
  }

  /// Processes pending requests from the queue with exponential backoff.
  Future<void> _processPendingRequests() async {
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
          final delayInSeconds = pow(2, request.retryCount);
          await Future.delayed(Duration(seconds: delayInSeconds.toInt()));

          final result = await postWithFailover(
            request.endpoint,
            request.body,
          );

          if (result.succeeded) {
            _requestQueue.removeRequest(request);
            if (debug) {
              debugPrint(
                '[CDP] Successfully processed queued request to ${request.endpoint} via ${result.lastBaseUrl}.',
              );
            }
          } else {
            request.retryCount++;
          }
        } catch (e) {
          request.retryCount++;
          if (debug) {
            debugPrint(
                '[CDP] Error processing queued request to ${request.endpoint}: $e. Retry count: ${request.retryCount}');
          }
        }

        if (request.retryCount > _maxRetries) {
          _requestQueue.removeRequest(request);
          if (debug) {
            debugPrint(
                '[CDP] Discarding request to ${request.endpoint} after reaching max retries.');
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }

    await _saveQueue();
  }

  /// Clears identity-specific data.
  Future<void> clearIdentity() async {
    try {
      await _processPendingRequests();

      _requestQueue.clear();

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
  void dispose() {
    try {
      _isProcessingQueue = false;
      _client.close();

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
