import 'dart:convert';
import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/logic/delegates.dart';
import 'package:hablotengo/logic/trust_pipeline.dart';
import 'package:hablotengo/main.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/ui/lgtm_dialog.dart';
import 'package:hablotengo/ui/ht_theme.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement_writer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:hablotengo/logic/hablo_cloud_functions.dart';
import 'package:hablotengo/logic/proof_builder.dart';

// ---------------------------------------------------------------------------
// Item type definitions
// ---------------------------------------------------------------------------

enum _Kind {
  email, phone,
  whatsapp, telegram, signal, instagram, twitter_x, threads, bluesky, mastodon,
  linkedin, facebook, website, other,
}

extension _KindX on _Kind {
  bool get supportsPreferred =>
      this == _Kind.email || this == _Kind.phone ||
      index >= _Kind.whatsapp.index && index <= _Kind.mastodon.index;

  String get label => const {
    _Kind.email: 'Email',
    _Kind.phone: 'Phone',
    _Kind.whatsapp: 'WhatsApp',
    _Kind.telegram: 'Telegram',
    _Kind.signal: 'Signal',
    _Kind.instagram: 'Instagram',
    _Kind.twitter_x: 'Twitter / X',
    _Kind.threads: 'Threads',
    _Kind.bluesky: 'Bluesky',
    _Kind.mastodon: 'Mastodon',
    _Kind.linkedin: 'LinkedIn',
    _Kind.facebook: 'Facebook',
    _Kind.website: 'Website',
    _Kind.other: 'Other',
  }[this]!;

  String get hint => const {
    _Kind.email: 'user@example.com',
    _Kind.phone: '+1 555 555 5555',
    _Kind.whatsapp: '+1 555 555 5555',
    _Kind.telegram: '@username',
    _Kind.signal: '+1 555 555 5555',
    _Kind.instagram: '@username',
    _Kind.twitter_x: '@username',
    _Kind.threads: '@username',
    _Kind.bluesky: 'user.bsky.social',
    _Kind.mastodon: '@user@instance.social',
    _Kind.linkedin: 'linkedin.com/in/username',
    _Kind.facebook: 'facebook.com/username',
    _Kind.website: 'https://',
    _Kind.other: 'Any other contact info',
  }[this]!;

  IconData get icon => const {
    _Kind.email: Icons.email_rounded,
    _Kind.phone: Icons.phone_rounded,
    _Kind.whatsapp: Icons.chat_rounded,
    _Kind.telegram: Icons.send_rounded,
    _Kind.signal: Icons.lock_rounded,
    _Kind.instagram: Icons.camera_alt_rounded,
    _Kind.twitter_x: Icons.alternate_email_rounded,
    _Kind.threads: Icons.tag_rounded,
    _Kind.bluesky: Icons.cloud_rounded,
    _Kind.mastodon: Icons.public_rounded,
    _Kind.linkedin: Icons.work_rounded,
    _Kind.facebook: Icons.people_rounded,
    _Kind.website: Icons.language_rounded,
    _Kind.other: Icons.more_horiz_rounded,
  }[this]!;
}

class _Item {
  final _Kind kind;
  final TextEditingController ctrl;
  bool preferred;
  _Item(this.kind, {String initial = '', this.preferred = false})
      : ctrl = TextEditingController(text: initial);
  void dispose() => ctrl.dispose();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key});
  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final List<_Item> _items = [];
  VisibilityLevel _visibility = VisibilityLevel.standard;
  bool _loading = true;
  bool _savingContact = false;
  bool _savingPrivacy = false;
  String? _error;
  List<DelegateKey> _myDelegateKeys = [];
  String? _loadedContactToken;
  String? _loadedPrivacyToken;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  Future<void> _loadCard() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pov = IdentityKey(signInState.pov);
      final trustSource = CloudFunctionsSource<TrustStatement>(
        baseUrl: oneofusTrustUrl,
        verifier: OouVerifier(),
      );
      final pipeline = TrustPipeline(trustSource);
      final graph = await pipeline.build(pov);
      final delegates = DelegateResolver(graph);
      delegates.resolveForIdentity(pov);
      _myDelegateKeys = delegates
          .getDelegatesForIdentity(pov)
          .where((dk) => delegates.getDomainForDelegate(dk) == kHablotengo)
          .toList();

      final delegateStatement = _myDelegateKeys.isNotEmpty
          ? findDelegateStatement(graph, pov, _myDelegateKeys.first.value)
          : null;

      final repo = ContactRepo(
        trustSource: trustSource,
        habloFirestore: habloFirestore,
        cloudFunctions: HabloCloudFunctions(habloFunctions),
      );
      final card = await repo.loadMyCard(_myDelegateKeys, delegateStatement: delegateStatement);

      _loadedContactToken = card.contact?.token;
      _loadedPrivacyToken = card.privacy?.token;

      if (card.contact != null) {
        final c = card.contact!;
        _nameCtrl.text = c.name ?? '';

        for (final e in c.emails) {
          _items.add(_Item(_Kind.email,
              initial: e['address'] ?? '',
              preferred: e['preferred'] == true));
        }
        for (final p in c.phones) {
          _items.add(_Item(_Kind.phone,
              initial: p['number'] ?? '',
              preferred: p['preferred'] == true));
        }
        c.contactPrefs.forEach((key, handles) {
          final kind = _Kind.values.firstWhere((k) => k.name == key, orElse: () => _Kind.other);
          for (final h in handles) {
            _items.add(_Item(kind,
                initial: h['handle'] ?? '',
                preferred: h['preferred'] == true));
          }
        });
        c.socialAccounts.forEach((key, value) {
          final kind = _Kind.values.firstWhere((k) => k.name == key, orElse: () => _Kind.other);
          if (value.isNotEmpty) _items.add(_Item(kind, initial: value));
        });
        if (c.website != null) _items.add(_Item(_Kind.website, initial: c.website!));
        if (c.other != null) _items.add(_Item(_Kind.other, initial: c.other!));
      }
      if (card.privacy != null) _visibility = card.privacy!.visibilityLevel;

      setState(() { _loading = false; });
    } catch (e, st) {
      // ignore: avoid_print
      print('MyCardScreen._loadCard ERROR: $e\n$st');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _addItem(_Kind kind) {
    setState(() => _items.add(_Item(kind)));
  }

  void _removeItem(_Item item) {
    setState(() {
      item.dispose();
      _items.remove(item);
    });
  }

  Map<String, dynamic> _buildContactJson(Map<String, dynamic> delegateJson) {
    final emails = <Map<String, dynamic>>[];
    final phones = <Map<String, dynamic>>[];
    final contactPrefs = <String, List<Map<String, dynamic>>>{};
    final socialAccounts = <String, String>{};
    String? website;
    String? other;

    for (final item in _items) {
      final val = item.ctrl.text.trim();
      if (val.isEmpty) continue;
      switch (item.kind) {
        case _Kind.email:
          emails.add({'address': val, 'preferred': item.preferred});
        case _Kind.phone:
          phones.add({'number': val, 'preferred': item.preferred});
        case _Kind.website:
          website = val;
        case _Kind.other:
          other = val;
        case _Kind.linkedin:
        case _Kind.facebook:
          socialAccounts[item.kind.name] = val;
        default:
          contactPrefs.putIfAbsent(item.kind.name, () => [])
              .add({'handle': val, 'preferred': item.preferred});
      }
    }

    return ContactStatement.buildJson(
      iJson: delegateJson,
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      emails: emails,
      phones: phones,
      contactPrefs: contactPrefs,
      socialAccounts: socialAccounts,
      website: website,
      other: other,
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;
    if (!signInState.canWrite) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No delegate key — cannot save')));
      return;
    }
    setState(() { _savingContact = true; _error = null; });
    try {
      final signer = signInState.signer!;
      final delegateJson = signInState.delegatePublicKeyJson!;
      final contactJson = _buildContactJson(delegateJson);

      if (mounted) {
        final ok = await LgtmDialog.check(contactJson, context, title: 'About to sign contact card');
        if (!ok) { setState(() { _savingContact = false; }); return; }
      }

      final stmt = await habloContactWriter.push(contactJson, signer,
          previous: ExpectedPrevious(_loadedContactToken));
      log('ContactStatement saved: ${const JsonEncoder.withIndent("  ").convert(stmt.json)}',
          name: 'hablotengo');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact info saved!')));
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('MyCardScreen._saveContact ERROR: $e\n$st');
      setState(() { _error = e.toString(); _savingContact = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _savePrivacy() async {
    if (!signInState.canWrite) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No delegate key — cannot save')));
      return;
    }
    setState(() { _savingPrivacy = true; _error = null; });
    try {
      final signer = signInState.signer!;
      final delegateJson = signInState.delegatePublicKeyJson!;
      final privacyJson = PrivacyStatement.buildJson(iJson: delegateJson, level: _visibility);

      if (mounted) {
        final ok = await LgtmDialog.check(privacyJson, context, title: 'About to sign visibility setting');
        if (!ok) { setState(() { _savingPrivacy = false; }); return; }
      }

      final stmt = await habloPrivacyWriter.push(privacyJson, signer,
          previous: ExpectedPrevious(_loadedPrivacyToken));
      log('PrivacyStatement saved: ${const JsonEncoder.withIndent("  ").convert(stmt.json)}',
          name: 'hablotengo');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visibility saved!')));
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('MyCardScreen._savePrivacy ERROR: $e\n$st');
      setState(() { _error = e.toString(); _savingPrivacy = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Card'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!signInState.canWrite)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Text('Read-only — sign in with a delegate key to edit',
                              style: TextStyle(color: Colors.deepOrange)),
                        ),
                      _sectionHeader('Name'),
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: signInState.canWrite,
                        decoration: const InputDecoration(
                          hintText: 'Your display name',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionHeader('Contact Methods'),
                      ..._items.map((item) => _ItemRow(
                            item: item,
                            canWrite: signInState.canWrite,
                            onRemove: () => _removeItem(item),
                            onPreferredToggle: () => setState(() {
                              if (item.preferred) {
                                item.preferred = false;
                              } else {
                                // Unset preferred for same kind
                                for (final other in _items) {
                                  if (other.kind == item.kind) other.preferred = false;
                                }
                                item.preferred = true;
                              }
                            }),
                          )),
                      if (signInState.canWrite) ...[
                        const SizedBox(height: 8),
                        _AddButton(onAdd: _addItem),
                      ],
                      const SizedBox(height: 24),
                      if (_savingContact)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: signInState.canWrite ? _saveContact : null,
                            child: const Text('Save Contact Info'),
                          ),
                        ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      _sectionHeader('Visibility'),
                      const Text('Who can see your card details',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ...VisibilityLevel.values.map((level) => RadioListTile<VisibilityLevel>(
                            title: Text(level.name),
                            subtitle: Text(_visibilityDesc(level)),
                            value: level,
                            groupValue: _visibility,
                            onChanged: signInState.canWrite ? (v) => setState(() => _visibility = v!) : null,
                          )),
                      const SizedBox(height: 16),
                      if (_savingPrivacy)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: signInState.canWrite ? _savePrivacy : null,
                            child: const Text('Save Visibility'),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.0)),
      );

  String _visibilityDesc(VisibilityLevel level) => switch (level) {
    VisibilityLevel.permissive => 'Anyone who believes you are a person (1 path, any distance)',
    VisibilityLevel.standard => '1 path at distance ≤2, 2 independent paths at distance 3+',
    VisibilityLevel.strict => '2 paths at distance 2–3, 3 paths at distance 4+',
  };
}

// ---------------------------------------------------------------------------
// Item row widget
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  final _Item item;
  final bool canWrite;
  final VoidCallback onRemove;
  final VoidCallback onPreferredToggle;
  const _ItemRow({
    required this.item,
    required this.canWrite,
    required this.onRemove,
    required this.onPreferredToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kGradientStart.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.kind.icon, size: 18, color: kGradientStart),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: item.ctrl,
              enabled: canWrite,
              decoration: InputDecoration(
                labelText: item.kind.label,
                hintText: item.kind.hint,
                isDense: true,
              ),
            ),
          ),
          if (item.kind.supportsPreferred) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: item.preferred ? 'Remove preferred' : 'Mark as preferred',
              child: IconButton(
                icon: Icon(
                  item.preferred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: item.preferred ? kGradientStart : Colors.grey.shade400,
                ),
                onPressed: canWrite ? onPreferredToggle : null,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          if (canWrite) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red.shade300, size: 20),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add button + picker
// ---------------------------------------------------------------------------

class _AddButton extends StatelessWidget {
  final void Function(_Kind) onAdd;
  const _AddButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add contact method'),
      onPressed: () => _showPicker(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: kGradientStart,
        side: const BorderSide(color: kGradientStart),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _KindPicker(onPick: (kind) {
        Navigator.pop(context);
        onAdd(kind);
      }),
    );
  }
}

class _KindPicker extends StatelessWidget {
  final void Function(_Kind) onPick;
  const _KindPicker({required this.onPick});

  static const _groups = [
    ('Basic', [_Kind.email, _Kind.phone]),
    ('Messaging', [_Kind.whatsapp, _Kind.telegram, _Kind.signal, _Kind.instagram,
                   _Kind.twitter_x, _Kind.threads, _Kind.bluesky, _Kind.mastodon]),
    ('Social & Web', [_Kind.linkedin, _Kind.facebook, _Kind.website, _Kind.other]),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add contact method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final (groupName, kinds) in _groups) ...[
            Text(groupName,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kinds.map((k) => ActionChip(
                    avatar: Icon(k.icon, size: 16, color: kGradientStart),
                    label: Text(k.label),
                    onPressed: () => onPick(k),
                    backgroundColor: kGradientStart.withOpacity(0.07),
                    labelStyle: const TextStyle(color: kGradientStart, fontSize: 13),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
