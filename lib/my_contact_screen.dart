import 'package:flutter/material.dart';

import 'contact_service.dart';
import 'models/contact_statement.dart';
import 'visibility_picker.dart';

class MyContactSheet extends StatefulWidget {
  final bool emulator;
  const MyContactSheet({super.key, required this.emulator});

  @override
  State<MyContactSheet> createState() => _MyContactSheetState();
}

class _MyContactSheetState extends State<MyContactSheet> {
  ContactData? _contact;
  bool _loading = true;
  String? _error;
  bool _editing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  List<_EditableEntry> _editEntries = [];
  int _nextEntryId = 0;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contact = await getMyContact(widget.emulator);
      if (mounted) setState(() { _contact = contact; _loading = false; });
    } catch (e, st) {
      debugPrint('MyContactSheet load error: $e\n$st');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _startEdit() {
    _nameCtrl.text = _contact?.name ?? '';
    _notesCtrl.text = _contact?.notes ?? '';
    _nextEntryId = 0;
    _editEntries = (_contact?.entries ?? [])
        .map((e) => _EditableEntry(_nextEntryId++, e))
        .toList();
    setState(() { _editing = true; _saveError = null; });
  }

  void _cancelEdit() => setState(() { _editing = false; _saveError = null; });

  Future<void> _save() async {
    setState(() { _saving = true; _saveError = null; });
    try {
      final contact = ContactData(
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        entries: _editEntries.map((e) => e.entry).where((e) => e.value.isNotEmpty).toList(),
      );
      await setMyContact(contact, widget.emulator);
      if (mounted) setState(() { _contact = contact; _editing = false; _saving = false; });
    } catch (e, st) {
      debugPrint('MyContactSheet save error: $e\n$st');
      if (mounted) setState(() { _saveError = e.toString(); _saving = false; });
    }
  }

  Future<void> _addEntry() async {
    final tech = await showDialog<String>(
      context: context,
      builder: (_) => const _TechPickerDialog(),
    );
    if (tech != null && tech.isNotEmpty) {
      setState(() => _editEntries.add(
          _EditableEntry(_nextEntryId++, ContactEntry(tech: tech, value: ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge!;
    const padding = EdgeInsets.fromLTRB(16, 16, 16, 24);

    if (_editing) {
      return SafeArea(
        child: Padding(
          padding: padding,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inline-editable name
                TextField(
                  controller: _nameCtrl,
                  style: titleStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: 'Name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: const UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                // Inline-editable notes
                TextField(
                  controller: _notesCtrl,
                  maxLines: null,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: 'Notes',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: const UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Entries', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    const VisibilityHelpButton(),
                  ],
                ),
                if (_saveError != null)
                  Text(_saveError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _editEntries.removeAt(oldIndex);
                              _editEntries.insert(newIndex, item);
                            });
                          },
                          children: [
                            for (int i = 0; i < _editEntries.length; i++)
                              _EditEntryRow(
                                key: ValueKey(_editEntries[i].id),
                                index: i,
                                entry: _editEntries[i].entry,
                                onChanged: (e) => setState(() =>
                                    _editEntries[i] = _EditableEntry(_editEntries[i].id, e)),
                                onDelete: () => setState(() => _editEntries.removeAt(i)),
                              ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addEntry,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add entry'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : _cancelEdit, child: const Text('Cancel')),
                    const SizedBox(width: 4),
                    ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // View mode
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _loading
                      ? const SizedBox.shrink()
                      : Text(
                          _contact?.name ?? '',
                          style: titleStyle,
                        ),
                ),
                if (!_loading && _error == null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: _startEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: Colors.red))
            else if (_contact == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No contact card yet.', style: TextStyle(color: Colors.grey)),
              )
            else ...[
              if (_contact!.notes != null) ...[
                const SizedBox(height: 6),
                Text(_contact!.notes!),
              ],
              if (_contact!.entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._contact!.entries.map((e) => ContactEntryViewRow(entry: e)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EditableEntry {
  final int id;
  final ContactEntry entry;
  const _EditableEntry(this.id, this.entry);
}

// ---------------------------------------------------------------------------

class ContactEntryViewRow extends StatelessWidget {
  final ContactEntry entry;
  const ContactEntryViewRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              entry.tech,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: SelectableText(entry.value, style: const TextStyle(fontSize: 14))),
          if (entry.preferred) const Icon(Icons.star, size: 14, color: Colors.amber),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TechPickerDialog extends StatefulWidget {
  const _TechPickerDialog();

  @override
  State<_TechPickerDialog> createState() => _TechPickerDialogState();
}

class _TechPickerDialogState extends State<_TechPickerDialog> {
  final _ctrl = TextEditingController();

  static const _common = ['email', 'phone', 'signal', 'whatsapp', 'instagram', 'tiktok', 'fax'];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add entry'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _common
                .map((t) => ActionChip(
                      label: Text(t),
                      onPressed: () => Navigator.pop(context, t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Or type a custom type',
              isDense: true,
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _EditEntryRow extends StatefulWidget {
  final int index;
  final ContactEntry entry;
  final ValueChanged<ContactEntry> onChanged;
  final VoidCallback onDelete;

  const _EditEntryRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_EditEntryRow> createState() => _EditEntryRowState();
}

class _EditEntryRowState extends State<_EditEntryRow> {
  late TextEditingController _valueCtrl;
  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(text: widget.entry.value);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _notify({bool? preferred, String? visibility}) {
    widget.onChanged(ContactEntry(
      tech: widget.entry.tech,
      value: _valueCtrl.text.trim(),
      preferred: preferred ?? widget.entry.preferred,
      visibility: visibility ?? widget.entry.visibility,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tech label is the drag handle
          ReorderableDragStartListener(
            index: widget.index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                width: 68,
                child: Text(
                  widget.entry.tech,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _valueCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _notify(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _notify(preferred: !widget.entry.preferred),
            child: Icon(
              widget.entry.preferred ? Icons.star : Icons.star_border,
              size: 18,
              color: widget.entry.preferred ? Colors.amber : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          VisibilityPicker(
            showLabels: false,
            value: widget.entry.visibility,
            onChanged: (v) => _notify(visibility: v),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onDelete,
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
