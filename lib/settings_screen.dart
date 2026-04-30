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
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default visibility', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Who can see your contact entries by default',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'permissive', label: Text('Permissive')),
                      ButtonSegment(value: 'standard', label: Text('Standard')),
                      ButtonSegment(value: 'strict', label: Text('Strict')),
                    ],
                    selected: {settingsState.defaultStrictness},
                    onSelectionChanged: (s) =>
                        settingsState.setDefaultStrictness(s.first, emulator),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
