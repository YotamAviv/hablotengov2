import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorDialog {
  static void show(BuildContext context, String title, Object error, [StackTrace? stackTrace]) {
    final String details = stackTrace != null
        ? 'Error: $error\n\nStack trace:\n$stackTrace'
        : 'Error: $error';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title.toUpperCase()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: $error', style: const TextStyle(fontSize: 13)),
              if (stackTrace != null) ...[
                const SizedBox(height: 16),
                const Text('STACK TRACE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Divider(),
                Text(stackTrace.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
            child: const Text('COPY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OKAY'),
          ),
        ],
      ),
    );
  }
}
