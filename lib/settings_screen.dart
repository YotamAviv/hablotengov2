import 'package:flutter/material.dart';

import 'settings_state.dart';

class SettingsScreen extends StatelessWidget {
  final bool emulator;
  const SettingsScreen({super.key, required this.emulator});

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
              onChanged: (v) => settingsState.setShowEmptyCards(v ?? false, emulator),
            ),
            CheckboxListTile(
              title: const Text('Show hidden cards'),
              subtitle: const Text('Include contacts who have restricted access to their card'),
              value: settingsState.showHiddenCards,
              onChanged: (v) => settingsState.setShowHiddenCards(v ?? false, emulator),
            ),
          ],
        ),
      ),
    );
  }
}
