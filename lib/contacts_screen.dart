import 'package:flutter/material.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'constants.dart';
import 'contact_service.dart';
import 'labeler.dart';
import 'settings_state.dart';
import 'sign_in_state.dart';

class _ContactEntry {
  final String name;
  final String token;
  final List<(String, String)> oldKeys;
  final List<String> monikers;
  _ContactEntry(this.name, this.token, this.oldKeys, this.monikers);
}

class ContactsScreen extends StatefulWidget {
  final bool emulator;
  const ContactsScreen({super.key, required this.emulator});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<_ContactEntry>? _contacts;
  Map<String, ContactResult>? _results;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final identityToken = signInState.identityToken!;
      debugPrint('ContactsScreen: building trust graph from $identityToken');

      final source = CloudFunctionsSource<TrustStatement>(
        baseUrl: oneofusExportUrl(widget.emulator),
        verifier: OouVerifier(),
      );
      final pipeline = TrustPipeline(source);
      final TrustGraph graph = await pipeline.build(IdentityKey(identityToken));

      debugPrint('ContactsScreen: trusted tokens=${graph.orderedKeys.length}');

      final labeler = Labeler(graph);

      final seen = <IdentityKey>{};
      final contacts = <_ContactEntry>[];
      for (final key in graph.orderedKeys) {
        final canonical = graph.resolveIdentity(key);
        if (canonical == graph.pov) continue;
        if (seen.contains(canonical)) continue;
        seen.add(canonical);

        final name = labeler.getIdentityLabel(canonical);
        final group = graph.getEquivalenceGroup(canonical);
        final oldKeys = group
            .where((k) => k != canonical)
            .map((k) => (labeler.getIdentityLabel(k), k.value))
            .toList();

        final monikers = labeler.getAllLabels(canonical);
        contacts.add(_ContactEntry(name, canonical.value, oldKeys, monikers));
      }

      setState(() => _contacts = contacts);

      // Batch-load all contact cards
      if (contacts.isNotEmpty) {
        final tokens = contacts.map((c) => c.token).toList();
        final results = await getBatchContacts(tokens, widget.emulator);
        if (mounted) setState(() => _results = results);
      }
    } catch (e, st) {
      debugPrint('ContactsScreen: error: $e\n$st');
      setState(() => _error = e.toString());
    }
  }

  bool _matchesSearch(_ContactEntry contact, ContactResult? result, String query) {
    if (contact.name.toLowerCase().contains(query)) return true;
    if (contact.monikers.any((m) => m.toLowerCase().contains(query))) return true;
    final card = result?.contact;
    if (card == null) return false;
    if (card.name.toLowerCase().contains(query)) return true;
    if (card.notes != null && card.notes!.toLowerCase().contains(query)) return true;
    return card.entries.any((e) =>
        e.tech.toLowerCase().contains(query) || e.value.toLowerCase().contains(query));
  }

  void _showContactDetail(BuildContext context, _ContactEntry contact) {
    final result = _results?[contact.token];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactDetailSheet(
        contact: contact,
        result: result,
        emulator: widget.emulator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: SelectableText('Error: $_error'));
    }
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contacts!.isEmpty) {
      return const Center(child: Text('No one in your network yet.'));
    }

    return ListenableBuilder(
      listenable: settingsState,
      builder: (context, _) {
        final query = _searchCtrl.text.toLowerCase();

        final visibleContacts = _contacts!.where((contact) {
          final status = _results?[contact.token]?.status;
          if (status == ContactStatus.notFound && !settingsState.showEmptyCards) return false;
          if (status == ContactStatus.denied && !settingsState.showHiddenCards) return false;
          if (query.isEmpty) return true;
          return _matchesSearch(contact, _results?[contact.token], query);
        }).toList();

        final items = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _searchCtrl.clear)
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (visibleContacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No contacts to show.')),
            ),
        ];
        for (final contact in visibleContacts) {
          final result = _results?[contact.token];
          items.add(
            InkWell(
              onTap: () => _showContactDetail(context, contact),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ContactNameWidget(contact: contact, result: result),
                    SelectableText(contact.token, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    for (final (label, tok) in contact.oldKeys) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            SelectableText(tok, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
          items.add(const Divider(height: 1));
        }

        return ListView(children: items);
      },
    );
  }
}

class _ContactNameWidget extends StatelessWidget {
  final _ContactEntry contact;
  final ContactResult? result;
  const _ContactNameWidget({required this.contact, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      // Still loading batch results
      return Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold));
    }
    return switch (result!.status) {
      ContactStatus.found => Text(
          result!.contact!.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ContactStatus.denied => Text(
          contact.name,
          style: const TextStyle(color: Color(0xFFE91E8C), fontStyle: FontStyle.italic),
        ),
      ContactStatus.notFound => Text(
          contact.name,
          style: const TextStyle(color: Color(0xFF4CAF50), fontStyle: FontStyle.italic),
        ),
    };
  }
}

class _ContactDetailSheet extends StatelessWidget {
  final _ContactEntry contact;
  final ContactResult? result;
  final bool emulator;
  const _ContactDetailSheet({required this.contact, required this.result, required this.emulator});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result?.status == ContactStatus.found
                  ? result!.contact!.name
                  : contact.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (contact.monikers.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(contact.monikers.join(', '), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            if (result == null)
              const Center(child: CircularProgressIndicator())
            else if (result!.status == ContactStatus.denied)
              const Text('Access denied.', style: TextStyle(color: Colors.grey))
            else if (result!.status == ContactStatus.notFound)
              const Text('No contact info.', style: TextStyle(color: Colors.grey))
            else ...[
              if (result!.contact!.notes != null) ...[
                SelectableText(result!.contact!.notes!),
                const SizedBox(height: 8),
              ],
              for (final entry in result!.contact!.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('${entry.tech}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: SelectableText(entry.value)),
                      if (entry.preferred)
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                    ],
                  ),
                ),
              if (result!.someHidden) ...[
                const SizedBox(height: 8),
                const Text(
                  'Some fields hidden due to access restrictions.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
