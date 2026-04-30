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
import 'models/contact_statement.dart';
import 'sign_in_state.dart';

class _ContactEntry {
  final String name;
  final String token;
  // Old keys in this person's equivalence group: (label, token)
  final List<(String, String)> oldKeys;
  _ContactEntry(this.name, this.token, this.oldKeys);
}

class ContactsScreen extends StatefulWidget {
  final bool emulator;
  const ContactsScreen({super.key, required this.emulator});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<_ContactEntry>? _contacts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

        debugPrint('ContactsScreen: $name token=${canonical.value} oldKeys=${oldKeys.length}');
        for (final (label, tok) in oldKeys) {
          debugPrint('  equivalent: $label token=$tok');
        }

        contacts.add(_ContactEntry(name, canonical.value, oldKeys));
      }

      setState(() => _contacts = contacts);
    } catch (e, st) {
      debugPrint('ContactsScreen: error: $e\n$st');
      setState(() => _error = e.toString());
    }
  }

  Future<void> _showContactDetail(BuildContext context, _ContactEntry contact) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactDetailSheet(contact: contact, emulator: widget.emulator),
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

    final items = <Widget>[];
    for (final contact in _contacts!) {
      items.add(
        InkWell(
          onTap: () => _showContactDetail(context, contact),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
  }
}

class _ContactDetailSheet extends StatefulWidget {
  final _ContactEntry contact;
  final bool emulator;
  const _ContactDetailSheet({required this.contact, required this.emulator});

  @override
  State<_ContactDetailSheet> createState() => _ContactDetailSheetState();
}

class _ContactDetailSheetState extends State<_ContactDetailSheet> {
  ContactData? _data;
  bool _loading = true;
  bool _forbidden = false;
  bool _noCard = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await getContact(widget.contact.token, widget.emulator);
      setState(() {
        _data = data;
        _loading = false;
        _noCard = data == null;
      });
    } on ContactAccessDeniedException {
      setState(() { _forbidden = true; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: Colors.red))
            else if (_forbidden)
              const Text('Access denied.', style: TextStyle(color: Colors.grey))
            else if (_noCard)
              const Text('No contact info.', style: TextStyle(color: Colors.grey))
            else ...[
              if (_data!.notes != null) ...[
                SelectableText(_data!.notes!),
                const SizedBox(height: 8),
              ],
              for (final entry in _data!.entries)
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
            ],
          ],
        ),
      ),
    );
  }
}
