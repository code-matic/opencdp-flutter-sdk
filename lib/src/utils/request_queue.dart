import 'dart:convert';

/// A class representing a queued request
class QueuedRequest {
  final String endpoint;
  final Map<String, dynamic> body;
  final String? identifier;
  final DateTime timestamp;

  QueuedRequest({
    required this.endpoint,
    required this.body,
    this.identifier,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'body': body,
        'identifier': identifier,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      endpoint: json['endpoint'] as String,
      body: json['body'] as Map<String, dynamic>,
      identifier: json['identifier'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// A queue for storing failed requests that need to be retried
class RequestQueue {
  final List<QueuedRequest> _queue = [];

  /// Add a failed request to the queue
  void addRequest(QueuedRequest request) {
    _queue.add(request);
  }

  /// Get all pending requests
  List<QueuedRequest> get pendingRequests => List.unmodifiable(_queue);

  /// Remove a request from the queue
  void removeRequest(QueuedRequest request) {
    _queue.remove(request);
  }

  /// Clear all requests from the queue
  void clear() {
    _queue.clear();
  }

  /// Check if the queue has any pending requests
  bool get hasRequests => _queue.isNotEmpty;

  /// Convert the queue to JSON for persistence
  String toJson() {
    return jsonEncode(_queue.map((r) => r.toJson()).toList());
  }

  /// Load the queue from JSON
  void fromJson(String json) {
    final List<dynamic> data = jsonDecode(json);
    _queue.clear();
    _queue.addAll(
      data.map((item) => QueuedRequest.fromJson(item as Map<String, dynamic>)),
    );
  }
}
