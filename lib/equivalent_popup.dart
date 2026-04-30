import 'package:flutter/material.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';

import 'equivalent_service.dart';
import 'settings_state.dart';

/// Shows a bottom sheet for each non-dismissed, non-disabled equivalent key.
/// Returns when all have been handled (disabled or dismissed).
/// Returns true if at least one equivalent was disabled (contacts should reload).
Future<bool> showEquivalentPopupsIfNeeded(
  BuildContext context,
  List<String> equivalentTokens,
  Map<String, String?> statusByToken,
  bool emulator,
) async {
  bool anyDisabled = false;
  for (final token in equivalentTokens) {
    if (!context.mounted) return anyDisabled;
    final disabledBy = statusByToken[token];
    if (disabledBy != null) continue;
    if (settingsState.dismissedEquivalents.contains(token)) continue;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _EquivalentSheet(token: token, emulator: emulator),
    );
    if (result == 'disabled') anyDisabled = true;
    if (result == null) return anyDisabled;
  }
  return anyDisabled;
}

class _EquivalentSheet extends StatefulWidget {
  final String token;
  final bool emulator;
  const _EquivalentSheet({required this.token, required this.emulator});

  @override
  State<_EquivalentSheet> createState() => _EquivalentSheetState();
}

class _EquivalentSheetState extends State<_EquivalentSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _mergeAndDisable() async {
    setState(() { _saving = true; _error = null; });
    try {
      await disableEquivalent(widget.token, mergeContact: true, emulator: widget.emulator);
      if (mounted) Navigator.pop(context, 'disabled');
    } catch (e) {
      debugPrint('_mergeAndDisable error: $e');
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Future<void> _dismiss() async {
    setState(() { _saving = true; _error = null; });
    try {
      await dismissEquivalent(widget.token, widget.emulator);
      settingsState.dismissedEquivalents = [...settingsState.dismissedEquivalents, widget.token];
      if (mounted) Navigator.pop(context, 'dismissed');
    } catch (e) {
      debugPrint('_dismiss error: $e');
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equivalent key found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'This key is equivalent to your active identity. '
              'You should either merge its data into your account and disable it, '
              'or dismiss this notice.',
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : _dismiss,
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _mergeAndDisable,
                  child: const Text('Merge & Disable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet shown when the signed-in account itself has been disabled.
Future<void> showDisabledAccountAlert(BuildContext context, String disabledBy, bool emulator, VoidCallback onSignOut) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _DisabledAccountSheet(disabledBy: disabledBy, emulator: emulator, onSignOut: onSignOut),
  );
}

class _DisabledAccountSheet extends StatefulWidget {
  final String disabledBy;
  final bool emulator;
  final VoidCallback onSignOut;
  const _DisabledAccountSheet({required this.disabledBy, required this.emulator, required this.onSignOut});

  @override
  State<_DisabledAccountSheet> createState() => _DisabledAccountSheetState();
}

class _DisabledAccountSheetState extends State<_DisabledAccountSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _enable() async {
    setState(() { _saving = true; _error = null; });
    try {
      await enableAccount(widget.emulator);
      settingsState.disabledBy = null;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('_enable error: $e');
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account disabled', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('This account has been disabled. Disabled by:'),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: JsonQrDisplay(widget.disabledBy)),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () {
                    Navigator.pop(context);
                    widget.onSignOut();
                  },
                  child: const Text('Sign out'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _enable,
                  child: const Text('Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
