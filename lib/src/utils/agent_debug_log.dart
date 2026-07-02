import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Debug-mode NDJSON logger for push notification investigation.
Future<void> agentDebugLog(
  String location,
  String message,
  Map<String, Object?> data, {
  String? hypothesisId,
  String runId = 'pre-fix',
}) async {
  if (!kDebugMode) return;
  // #region agent log
  final payload = <String, Object?>{
    'sessionId': '5ccecb',
    'runId': runId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    if (hypothesisId != null) 'hypothesisId': hypothesisId,
  };
  debugPrint('[agent-debug] ${jsonEncode(payload)}');
  try {
    final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    await http
        .post(
          Uri.parse('http://$host:7605/ingest/1ccf1d2a-1f57-4b7f-94c7-5404e2195d21'),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '5ccecb',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    try {
      if (Platform.isMacOS) {
        File('/Users/mac/CodeMatic/aella/.cursor/debug-5ccecb.log').writeAsStringSync(
          '${jsonEncode(payload)}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {}
  }
  // #endregion
}
