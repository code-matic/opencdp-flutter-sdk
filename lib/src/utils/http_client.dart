import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP client wrapper for CDP API calls
class CDPHttpClient {
  final http.Client _client;
  final String baseUrl;
  final String apiKey;
  final bool debug;

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
  }) : _client = client ?? http.Client();

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
        throw CDPException(
          'Failed to make request to $endpoint: ${response.body}',
          response.statusCode,
        );
      }

      if (debug) {
        final action = endpoint.split('/').last;
        final id = identifier ?? 'unknown';
        debugPrint('[CDP] $action for $id');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (debug) {
        debugPrint('[CDP] Error making request to $endpoint: $e');
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
