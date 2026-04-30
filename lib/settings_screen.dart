import 'package:flutter/material.dart';

import 'settings_state.dart';
import 'visibility_picker.dart';

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
                    onChanged: (v) => settingsState.setDefaultStrictness(v, emulator),
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
