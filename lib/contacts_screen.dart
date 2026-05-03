import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'contact_service.dart';
import 'equivalent_popup.dart';
import 'equivalent_service.dart';
import 'labeler.dart';
import 'my_contact_screen.dart' show ContactEntryViewRow, MyContactSheet;
import 'settings_state.dart';
import 'sign_in_state.dart';

List<String> _sortKey(String name) {
  final cleaned = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.reversed.toList();
}

class _ContactEntry {
  final String name;
  final String token;
  final List<(String, String)> myOldKeys;
  final List<String> monikers;
  _ContactEntry(this.name, this.token, this.myOldKeys, this.monikers);
}

class ContactsScreen extends StatefulWidget {
  final bool emulator;
  final String? startupTarget;
  final ValueNotifier<bool>? isLoading;
  const ContactsScreen({super.key, required this.emulator, this.startupTarget, this.isLoading});

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
  List<_ContactEntry>? _contacts;
  Map<String, ContactResult>? _results;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  late final ValueNotifier<bool> _loadingNotifier;

  @override
  void initState() {
    super.initState();
    _loadingNotifier = widget.isLoading ?? ValueNotifier(true);
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.isLoading == null) _loadingNotifier.dispose();
    super.dispose();
  }

  void reload() => _load();

  List<String> get myMonikers {
    final me = _contacts?.firstWhere(
      (c) => c.token == signInState.identityToken,
      orElse: () => _ContactEntry('', '', [], []),
    );
    return me?.monikers ?? [];
  }

  Future<void> _load() async {
    _loadingNotifier.value = true;
    try {
      final identityToken = signInState.identityToken!;
      debugPrint('ContactsScreen: building trust graph from $identityToken');

      final source = CloudFunctionsSource<TrustStatement>(
        baseUrl: oneofusExportUrl(widget.emulator),
        verifier: OouVerifier(),
      );
      final pipeline = TrustPipeline(source);
      final TrustGraph graph = await pipeline.build(IdentityKey(identityToken));

      debugPrint('ContactsScreen: pov=${graph.pov.value}');
      debugPrint('ContactsScreen: trusted tokens=${graph.orderedKeys.length}');
      debugPrint('ContactsScreen: orderedKeys=${graph.orderedKeys.map((k) => k.value.substring(0, 8)).join(', ')}');
      final povGroup = graph.getEquivalenceGroup(graph.pov);
      debugPrint('ContactsScreen: pov equivalenceGroup=${povGroup.map((k) => k.value.substring(0, 8)).join(', ')}');
      debugPrint('ContactsScreen: equivalent2canonical=${graph.equivalent2canonical.entries.map((e) => '${e.key.value.substring(0, 8)}→${e.value.value.substring(0, 8)}').join(', ')}');
      for (final key in graph.orderedKeys) {
        final canonical = graph.resolveIdentity(key);
        if (canonical != key) {
          debugPrint('ContactsScreen: resolveIdentity ${key.value.substring(0, 8)} → ${canonical.value.substring(0, 8)}');
        }
      }

      final labeler = Labeler(graph);

      final seen = <IdentityKey>{};
      final contacts = <_ContactEntry>[];
      for (final key in graph.orderedKeys) {
        final canonical = graph.resolveIdentity(key);
        if (seen.contains(canonical)) continue;
        seen.add(canonical);

        final name = labeler.getIdentityLabel(canonical);
        final group = graph.getEquivalenceGroup(canonical);
        final myOldKeys = group
            .where((k) => k != canonical)
            .map((k) => (labeler.getIdentityLabel(k), k.value))
            .toList();

        final monikers = labeler.getAllLabels(canonical);
        contacts.add(_ContactEntry(name, canonical.value, myOldKeys, monikers));
      }

      setState(() => _contacts = contacts);

      // Check for undismissed, non-disabled equivalent keys on the signed-in user's identity.
      final myOldKeys = graph.getEquivalenceGroup(graph.pov)
          .where((k) => k != graph.pov)
          .map((k) => k.value)
          .toList();
      if (myOldKeys.isNotEmpty && mounted && signInState.hasDelegate) {
        final status = await getEquivalentStatus(myOldKeys, widget.emulator);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final anyDisabled = await showEquivalentPopupsIfNeeded(context, myOldKeys, status, widget.emulator);
              if (mounted && anyDisabled) _load();
            }
          });
        }
      }

      // Batch-load all contact cards
      if (contacts.isNotEmpty) {
        final tokens = contacts.map((c) => c.token).toList();
        final results = await getBatchContacts(tokens, widget.emulator);
        if (mounted) setState(() => _results = results);
      }

      // Auto-open contact detail after results are ready
      if (widget.startupTarget != null && mounted) {
        final target = contacts.firstWhere(
          (c) => c.token == widget.startupTarget,
          orElse: () => contacts.firstWhere(
            (c) => c.myOldKeys.any((k) => k.$2 == widget.startupTarget),
            orElse: () => contacts.first,
          ),
        );
        if (target.token == widget.startupTarget ||
            target.myOldKeys.any((k) => k.$2 == widget.startupTarget)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showContactDetail(context, target);
          });
        }
      }
    } catch (e, st) {
      debugPrint('ContactsScreen: error: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) _loadingNotifier.value = false;
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
    if (contact.token == signInState.identityToken) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => MyContactSheet(emulator: widget.emulator, monikers: contact.monikers),
      );
      return;
    }
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

        visibleContacts.sort((a, b) {
          final aName = _results?[a.token]?.status == ContactStatus.found
              ? _results![a.token]!.contact!.name : a.name;
          final bName = _results?[b.token]?.status == ContactStatus.found
              ? _results![b.token]!.contact!.name : b.name;
          final aKey = _sortKey(aName);
          final bKey = _sortKey(bName);
          for (int i = 0; i < aKey.length && i < bKey.length; i++) {
            final cmp = aKey[i].toLowerCase().compareTo(bKey[i].toLowerCase());
            if (cmp != 0) return cmp;
          }
          return aKey.length.compareTo(bKey.length);
        });

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
      return Text(contact.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black38));
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

  Uri _nerdsterUri({
    required String povPayload,
    required String targetPayload,
    required String identityPathsReq,
  }) {
    return Uri.parse(nerdsterAppUrl(emulator)).replace(queryParameters: {
      if (emulator) 'fire': 'emulator',
      'pov': povPayload,
      'target': targetPayload,
      'fcontext': '<identity>',
      'identityPathsReq': identityPathsReq,
    });
  }

  @override
  Widget build(BuildContext context) {
    final String myPayload = jsonEncode(FedKey(signInState.identityJson!, kNativeEndpoint).toPayload());
    final String contactPayload = jsonEncode(FedKey.find(IdentityKey(contact.token))!.toPayload());

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
                ContactEntryViewRow(entry: entry),
              if (result!.someHidden) ...[
                const SizedBox(height: 8),
                const Text(
                  'Some fields hidden due to access restrictions.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ],
            ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.hub, size: 16),
                    label: const Text('You → them'),
                    onPressed: () => launchUrl(
                      _nerdsterUri(
                        povPayload: myPayload,
                        targetPayload: contactPayload,
                        identityPathsReq: settingsState.defaultStrictness,
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.hub, size: 16),
                    label: const Text('Them → you'),
                    onPressed: () => launchUrl(
                      _nerdsterUri(
                        povPayload: contactPayload,
                        targetPayload: myPayload,
                        identityPathsReq: result?.defaultStrictness ?? 'standard',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
