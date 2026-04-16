import 'dart:convert';
import 'package:flutter/material.dart';

class LgtmDialog {
  static Future<bool> check(Map<String, dynamic> json, BuildContext context, {String? title}) async {
    final pretty = const JsonEncoder.withIndent('  ').convert(json);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? 'About to sign and save'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Looks Good To Me')),
        ],
      ),
    );
    return result == true;
  }
}
