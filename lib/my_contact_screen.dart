import 'package:flutter/material.dart';

import 'contact_service.dart';
import 'models/contact_statement.dart';
import 'sign_in_state.dart';

class MyContactScreen extends StatefulWidget {
  final bool emulator;
  const MyContactScreen({super.key, required this.emulator});

  @override
  State<MyContactScreen> createState() => _MyContactScreenState();
}

class _MyContactScreenState extends State<MyContactScreen> {
  ContactData? _contact;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contact = await getMyContact(widget.emulator);
      setState(() {
        _contact = contact;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('MyContactScreen load error: $e\n$st');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: SelectableText('Error: $_error')));

    return Scaffold(
      appBar: AppBar(title: const Text('My Card')),
      body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _contact?.name ?? '(no contact card)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openEditor(context),
                child: const Text('Edit'),
              ),
            ],
          ),
          if (_contact?.notes != null) ...[
            const SizedBox(height: 8),
            SelectableText(_contact!.notes!),
          ],
          const SizedBox(height: 16),
          for (final entry in _contact?.entries ?? [])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text('${entry.tech}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: SelectableText(entry.value)),
                  if (entry.preferred)
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SelectableText(
            'Identity: ${signInState.identityToken}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final updated = await showDialog<ContactData>(
      context: context,
      builder: (_) => _ContactEditor(initial: _contact, emulator: widget.emulator),
    );
    if (updated != null) {
      setState(() => _contact = updated);
    }
  }
}

class _ContactEditor extends StatefulWidget {
  final ContactData? initial;
  final bool emulator;
  const _ContactEditor({required this.initial, required this.emulator});

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late List<ContactEntry> _entries;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _notesCtrl = TextEditingController(text: widget.initial?.notes ?? '');
    _entries = List.of(widget.initial?.entries ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Contact Card', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 16),
              Text('Entries', style: Theme.of(context).textTheme.titleMedium),
              for (int i = 0; i < _entries.length; i++)
                _EntryRow(
                  entry: _entries[i],
                  onChanged: (e) => setState(() => _entries[i] = e),
                  onDelete: () => setState(() => _entries.removeAt(i)),
                ),
              TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add entry'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addEntry() {
    setState(() => _entries.add(const ContactEntry(tech: 'email', value: '')));
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final contact = ContactData(
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        entries: _entries.where((e) => e.value.isNotEmpty).toList(),
      );
      await setMyContact(contact, widget.emulator);
      if (mounted) Navigator.pop(context, contact);
    } catch (e, st) {
      debugPrint('_ContactEditor save error: $e\n$st');
      setState(() { _error = e.toString(); _saving = false; });
    }
  }
}

class _EntryRow extends StatefulWidget {
  final ContactEntry entry;
  final ValueChanged<ContactEntry> onChanged;
  final VoidCallback onDelete;
  const _EntryRow({required this.entry, required this.onChanged, required this.onDelete});

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  late TextEditingController _techCtrl;
  late TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _techCtrl = TextEditingController(text: widget.entry.tech);
    _valueCtrl = TextEditingController(text: widget.entry.value);
  }

  @override
  void dispose() {
    _techCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(ContactEntry(
      tech: _techCtrl.text.trim(),
      value: _valueCtrl.text.trim(),
      preferred: widget.entry.preferred,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _techCtrl,
            decoration: const InputDecoration(labelText: 'tech'),
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _valueCtrl,
            decoration: const InputDecoration(labelText: 'value'),
            onChanged: (_) => _notify(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }
}
