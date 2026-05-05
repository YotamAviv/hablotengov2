import 'package:flutter/material.dart';

import 'contact_service.dart';
import 'settings_state.dart';
import 'sign_in_state.dart';
import 'visibility_picker.dart';

class SettingsScreen extends StatefulWidget {
  final bool emulator;
  const SettingsScreen({super.key, required this.emulator});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;
  bool _saving = false;

  late bool _showEmptyCards;
  late bool _showHiddenCards;
  late bool _showCrypto;
  late String _strictness;

  @override
  void initState() {
    super.initState();
    _showEmptyCards  = settingsState.showEmptyCards;
    _showHiddenCards = settingsState.showHiddenCards;
    _showCrypto      = settingsState.showCrypto;
    _strictness      = settingsState.defaultStrictness;
  }

  bool get _dirty =>
      _showEmptyCards  != settingsState.showEmptyCards  ||
      _showHiddenCards != settingsState.showHiddenCards ||
      _showCrypto      != settingsState.showCrypto      ||
      _strictness      != settingsState.defaultStrictness;

  void _cancel() => setState(() {
    _showEmptyCards  = settingsState.showEmptyCards;
    _showHiddenCards = settingsState.showHiddenCards;
    _showCrypto      = settingsState.showCrypto;
    _strictness      = settingsState.defaultStrictness;
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_showEmptyCards  != settingsState.showEmptyCards)  await settingsState.setShowEmptyCards(_showEmptyCards);
      if (_showHiddenCards != settingsState.showHiddenCards) await settingsState.setShowHiddenCards(_showHiddenCards);
      if (_showCrypto      != settingsState.showCrypto)      await settingsState.setShowCrypto(_showCrypto);
      if (_strictness      != settingsState.defaultStrictness) await settingsState.setDefaultStrictness(_strictness, widget.emulator);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    return PopScope(
      canPop: !_dirty,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _dirty ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          children: [
            CheckboxListTile(
              title: const Text('Show empty cards'),
              subtitle: const Text('Include contacts who have no card in the system'),
              value: _showEmptyCards,
              onChanged: (v) => setState(() => _showEmptyCards = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Show hidden cards'),
              subtitle: const Text('Include contacts who have restricted access to their card'),
              value: _showHiddenCards,
              onChanged: (v) => setState(() => _showHiddenCards = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Show crypto'),
              subtitle: const Text('Show signed statement on contact cards for auditing'),
              value: _showCrypto,
              onChanged: (v) => setState(() => _showCrypto = v ?? false),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Opacity(
                opacity: signInState.hasDelegate ? 1.0 : 0.38,
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
                    AbsorbPointer(
                      absorbing: !signInState.hasDelegate,
                      child: VisibilityPicker(
                        value: _strictness,
                        onChanged: (v) => setState(() => _strictness = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (signInState.hasDelegate) ...[
              const Divider(),
              ListTile(
                leading: _deleting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete account', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete my data'),
                onTap: _deleting ? null : _confirmDelete,
              ),
            ],
          ],
        ),
        bottomNavigationBar: _dirty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _saving ? null : _cancel, child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
