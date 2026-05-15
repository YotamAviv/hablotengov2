import 'package:flutter/material.dart';

import 'settings_state.dart';

class SettingsScreen extends StatefulWidget {
  final bool emulator;
  const SettingsScreen({super.key, required this.emulator});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saving = false;

  late bool _showEmptyCards;
  late bool _showHiddenCards;
  late bool _showCrypto;

  @override
  void initState() {
    super.initState();
    _showEmptyCards  = settingsState.showEmptyCards;
    _showHiddenCards = settingsState.showHiddenCards;
    _showCrypto      = settingsState.showCrypto;
  }

  bool get _dirty =>
      _showEmptyCards  != settingsState.showEmptyCards  ||
      _showHiddenCards != settingsState.showHiddenCards ||
      _showCrypto      != settingsState.showCrypto;

  void _cancel() => setState(() {
    _showEmptyCards  = settingsState.showEmptyCards;
    _showHiddenCards = settingsState.showHiddenCards;
    _showCrypto      = settingsState.showCrypto;
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_showEmptyCards  != settingsState.showEmptyCards)  await settingsState.setShowEmptyCards(_showEmptyCards);
      if (_showHiddenCards != settingsState.showHiddenCards) await settingsState.setShowHiddenCards(_showHiddenCards);
      if (_showCrypto      != settingsState.showCrypto)      await settingsState.setShowCrypto(_showCrypto);
    } finally {
      if (mounted) setState(() => _saving = false);
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
