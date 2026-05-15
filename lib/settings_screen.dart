import 'package:flutter/material.dart';

import 'settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        child: ListenableBuilder(
          listenable: settingsState,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Show empty cards'),
                subtitle: const Text('Include contacts who have no card in the system'),
                value: settingsState.showEmptyCards,
                onChanged: (v) => settingsState.setShowEmptyCards(v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Show hidden cards'),
                subtitle: const Text('Include contacts who have restricted access to their card'),
                value: settingsState.showHiddenCards,
                onChanged: (v) => settingsState.setShowHiddenCards(v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Show crypto'),
                subtitle: const Text('Show signed statement on contact cards for auditing'),
                value: settingsState.showCrypto,
                onChanged: (v) => settingsState.setShowCrypto(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
