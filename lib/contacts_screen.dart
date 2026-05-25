import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oneofus_common/keys.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'contact_service.dart';
import 'models/contact_statement.dart' show ContactData;
import 'export_keys_button.dart';
import 'my_contact_screen.dart' show ContactEntryViewRow, MyContactSheet;
import 'settings_state.dart';
import 'sign_in_state.dart';

List<String> _sortKey(String name) {
  final cleaned = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.reversed.toList();
}

class ContactsScreen extends StatefulWidget {
  final bool emulator;
  final String? startupTarget;
  final ValueNotifier<bool>? isLoading;
  final ValueNotifier<bool>? isDelegateError;
  final void Function(bool hasCard)? onContactCardStatus;
  const ContactsScreen({
    super.key,
    required this.emulator,
    this.startupTarget,
    this.isLoading,
    this.isDelegateError,
    this.onContactCardStatus,
  });

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
  List<TrustContact>? _contacts;
  Map<String, TrustContact>? _results;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  late final ValueNotifier<bool> _loadingNotifier;
  late final ValueNotifier<bool> _delegateErrorNotifier;

  @override
  void initState() {
    super.initState();
    _loadingNotifier = widget.isLoading ?? ValueNotifier(true);
    _delegateErrorNotifier = widget.isDelegateError ?? ValueNotifier(false);
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.isLoading == null) _loadingNotifier.dispose();
    if (widget.isDelegateError == null) _delegateErrorNotifier.dispose();
    super.dispose();
  }

  void reload() => _load();

  TrustContact? get myContactResult => _results?[signInState.identityToken];

  void updateMyContact(ContactData contact) {
    final selfToken = signInState.identityToken;
    if (selfToken == null || _results == null) return;
    final existing = _results![selfToken];
    if (existing == null) return;
    setState(() {
      final updated = existing.withContact(contact);
      _results![selfToken] = updated;
      final idx = _contacts?.indexWhere((c) => c.token == selfToken) ?? -1;
      if (idx >= 0) _contacts![idx] = updated;
    });
  }

  List<String> get myMonikers {
    final self = _results?[signInState.identityToken];
    return self?.monikers ?? [];
  }

  Future<void> _load() async {
    _loadingNotifier.value = true;
    _delegateErrorNotifier.value = false;
    try {
      final data = await getBatchContacts(widget.emulator);

      if (mounted) {
        setState(() {
          _contacts = data.contacts;
          _results = data.byToken;
          _error = null;
        });
        settingsState.applyServerSettings(
          data.byToken[data.selfToken]?.contact?.defaultStrictness,
        );
        widget.onContactCardStatus?.call(
          data.byToken[data.selfToken]?.rawStatement != null,
        );
      }

      // Auto-open contact detail after results are ready
      if (widget.startupTarget != null && mounted) {
        final contacts = data.contacts;
        final target = contacts.firstWhere(
          (c) => c.token == widget.startupTarget,
          orElse: () => contacts.first,
        );
        if (target.token == widget.startupTarget) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showContactDetail(context, target);
          });
        }
      }
    } catch (e, st) {
      debugPrint('ContactsScreen: error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  bool _matchesSearch(TrustContact contact, String query) {
    final label = contact.label ?? '';
    if (label.toLowerCase().contains(query)) return true;
    if (contact.monikers.any((m) => m.toLowerCase().contains(query))) return true;
    final card = contact.contact;
    if (card == null) return false;
    if (card.name.toLowerCase().contains(query)) return true;
    if (card.notes != null && card.notes!.toLowerCase().contains(query)) return true;
    return card.entries.any(
      (e) => e.tech.toLowerCase().contains(query) || e.value.toLowerCase().contains(query),
    );
  }

  void _showContactDetail(BuildContext context, TrustContact contact) {
    if (contact.token == signInState.identityToken) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => MyContactSheet(
          emulator: widget.emulator,
          monikers: contact.monikers,
          isLoading: _loadingNotifier,
          preloaded: contact,
          onContactSaved: updateMyContact,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactDetailSheet(
        contact: contact,
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
          final status = contact.status;
          if (status == ContactStatus.notFound && !settingsState.showEmptyCards) return false;
          if (status == ContactStatus.denied && !settingsState.showHiddenCards) return false;
          if (query.isEmpty) return true;
          return _matchesSearch(contact, query);
        }).toList();

        visibleContacts.sort((a, b) {
          final aName = a.status == ContactStatus.found
              ? a.contact!.name
              : (a.label ?? '');
          final bName = b.status == ContactStatus.found
              ? b.contact!.name
              : (b.label ?? '');
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
          items.add(
            InkWell(
              onTap: () => _showContactDetail(context, contact),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_ContactNameWidget(contact: contact)],
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
  final TrustContact contact;
  const _ContactNameWidget({required this.contact});

  @override
  Widget build(BuildContext context) {
    return switch (contact.status) {
      ContactStatus.found => Text(
        contact.contact!.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      ContactStatus.denied => Text(
        contact.label ?? '',
        style: const TextStyle(color: Color(0xFFE91E8C), fontStyle: FontStyle.italic),
      ),
      ContactStatus.notFound => Text(
        contact.label ?? '',
        style: const TextStyle(color: Color(0xFF4CAF50), fontStyle: FontStyle.italic),
      ),
    };
  }
}

class _ContactDetailSheet extends StatelessWidget {
  final TrustContact contact;
  final bool emulator;
  const _ContactDetailSheet({required this.contact, required this.emulator});

  Uri _nerdsterUri({
    required String povPayload,
    required String targetPayload,
    required String identityPathsReq,
  }) {
    return Uri.parse(nerdsterAppUrl(emulator)).replace(
      queryParameters: {
        if (emulator) 'fire': 'emulator',
        'pov': povPayload,
        'target': targetPayload,
        'fcontext': '<identity>',
        'identityPathsReq': identityPathsReq,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myPayload = jsonEncode(FedKey(signInState.identityJson!, kNativeEndpoint).toPayload());
    final contactPayload = contact.keyPayload != null ? jsonEncode(contact.keyPayload) : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.status == ContactStatus.found ? contact.contact!.name : (contact.label ?? ''),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (contact.monikers.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                contact.monikers.join(', '),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            if (contact.status == ContactStatus.denied)
              const Text('Access denied.', style: TextStyle(color: Colors.grey))
            else if (contact.status == ContactStatus.notFound)
              const Text('No contact info.', style: TextStyle(color: Colors.grey))
            else ...[
              if (contact.contact!.notes != null) ...[
                SelectableText(contact.contact!.notes!),
                const SizedBox(height: 8),
              ],
              for (final entry in contact.contact!.entries) ContactEntryViewRow(entry: entry),
              if (contact.someHidden) ...[
                const SizedBox(height: 8),
                const Text(
                  'Some fields hidden due to access restrictions.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
              if (settingsState.showCrypto && contact.rawStatement != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    ExportKeysButton(rawStatement: contact.rawStatement!, emulator: emulator),
                  ],
                ),
              ],
            ],
            if (contactPayload != null) ...[
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
                        identityPathsReq: contact.defaultStrictness,
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
