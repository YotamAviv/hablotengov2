import 'package:flutter/material.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'constants.dart';
import 'labeler.dart';
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(contact.token, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              for (final (label, tok) in contact.oldKeys) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      SelectableText(tok, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      items.add(const Divider(height: 1));
    }

    return ListView(children: items);
  }
}
