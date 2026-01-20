import 'package:flutter/material.dart';

import '../services/log_service.dart';

class ConsoleView extends StatelessWidget {
  const ConsoleView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LogService.instance,
      builder: (context, _) {
        final logs = LogService.instance.logs;
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              'No logs yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: logs.length,
          reverse:
              true, // Show newest at the bottom naturally, but listview reverse puts index 0 at bottom.
          // Actually, we want newest at the bottom.
          // If we use reverse: true, index 0 is at the bottom.
          // If logs are appended, index 0 is oldest.
          // So reverse: true makes oldest at bottom.
          // Let's stick to standard order, but scroll to end?
          // Or just show newest at top (reverse order of list)
          // Let's show newest at the top for easier reading on mobile.
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            // Reverse index to show newest first
            final entry = logs[logs.length - 1 - index];
            return _LogItem(entry: entry);
          },
        );
      },
    );
  }
}

class _LogItem extends StatelessWidget {
  final LogEntry entry;

  const _LogItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (entry.type) {
      case LogType.error:
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      case LogType.success:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case LogType.info:
        color = Colors.grey[700]!;
        icon = Icons.info_outline;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(entry.timestamp),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
