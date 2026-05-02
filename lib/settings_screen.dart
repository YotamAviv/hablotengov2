import 'package:flutter/material.dart';

import 'contact_service.dart';
import 'settings_state.dart';
import 'visibility_picker.dart';

class SettingsScreen extends StatefulWidget {
  final bool emulator;
  const SettingsScreen({super.key, required this.emulator});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your contact card and settings from the server. ',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await deleteAccount(widget.emulator);
      settingsState.reset();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settingsState,
        builder: (context, _) => ListView(
          children: [
            CheckboxListTile(
              title: const Text('Show empty cards'),
              subtitle: const Text('Include contacts who have no card in the system'),
              value: settingsState.showEmptyCards,
              onChanged: (v) => settingsState.setShowEmptyCards(v ?? false, widget.emulator),
            ),
            CheckboxListTile(
              title: const Text('Show hidden cards'),
              subtitle: const Text('Include contacts who have restricted access to their card'),
              value: settingsState.showHiddenCards,
              onChanged: (v) => settingsState.setShowHiddenCards(v ?? false, widget.emulator),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Default visibility', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 6),
                      const VisibilityHelpButton(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Who can see your contact entries by default',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  VisibilityPicker(
                    value: settingsState.defaultStrictness,
                    onChanged: (v) => settingsState.setDefaultStrictness(v, widget.emulator),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: _deleting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete account', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Remove your contact card and settings from the server'),
              onTap: _deleting ? null : _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}
