import 'package:flutter/foundation.dart';

/// A simple service to manage application logs.
///
/// This service uses a singleton pattern to ensure logs are accessible
/// from anywhere in the application. It notifies listeners when new logs are added.
class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  static LogService get instance => _instance;

  LogService._internal();

  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {LogType type = LogType.info}) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      type: type,
    );
    _logs.add(entry);
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

enum LogType { info, error, success }

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogType type;

  LogEntry({
    required this.message,
    required this.timestamp,
    this.type = LogType.info,
  });
}
