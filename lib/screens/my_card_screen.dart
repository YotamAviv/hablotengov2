import 'dart:developer' show log;
import 'dart:convert';
import 'package:hablotengo/ui/lgtm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/logic/delegates.dart';
import 'package:hablotengo/logic/hablo_statement_writer.dart';
import 'package:hablotengo/main.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:hablotengo/logic/trust_pipeline.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/constants.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';

class MyCardScreen extends StatefulWidget {
  const MyCardScreen({super.key});

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _savingContact = false;
  bool _savingPrivacy = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _signalCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _threadsCtrl = TextEditingController();
  final _bskyCtrl = TextEditingController();
  final _mastodonCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  VisibilityLevel _visibility = VisibilityLevel.standard;

  List<DelegateKey> _myDelegateKeys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Resolve my delegate keys from the trust graph
      final trustSource = DirectFirestoreSource<TrustStatement>(oneofusFirestore);
      final pipeline = TrustPipeline(trustSource);
      final pov = IdentityKey(signInState.pov);
      final graph = await pipeline.build(pov);
      final resolver = DelegateResolver(graph);
      resolver.resolveForIdentity(pov);
      _myDelegateKeys = resolver.getDelegatesForIdentity(pov)
          .where((dk) => resolver.getDomainForDelegate(dk) == kHablotengo)
          .toList();

      // Also include current session delegate key if not yet in the trust graph
      final sessionDelegate = signInState.delegate;
      if (sessionDelegate != null) {
        final sessionKey = DelegateKey(sessionDelegate);
        if (!_myDelegateKeys.any((k) => k.value == sessionDelegate)) {
          _myDelegateKeys.add(sessionKey);
        }
      }

      final repo = ContactRepo(oneofusFirestore: oneofusFirestore, habloFirestore: habloFirestore);
      final card = await repo.loadMyCard(_myDelegateKeys);

      if (card.contact != null) {
        _nameCtrl.text = card.contact!.name ?? '';
        _emailCtrl.text = card.contact!.emails.isNotEmpty
            ? (card.contact!.emails.first['address'] ?? '')
            : '';
        _phoneCtrl.text = card.contact!.phone ?? '';
        final cp = card.contact!.contactPrefs;
        _whatsappCtrl.text = _handle(cp, 'whatsapp');
        _telegramCtrl.text = _handle(cp, 'telegram');
        _signalCtrl.text = _handle(cp, 'signal');
        _instagramCtrl.text = _handle(cp, 'instagram');
        _twitterCtrl.text = _handle(cp, 'twitter_x');
        _threadsCtrl.text = _handle(cp, 'threads');
        _bskyCtrl.text = _handle(cp, 'bluesky');
        _mastodonCtrl.text = _handle(cp, 'mastodon');
        final sa = card.contact!.socialAccounts;
        _linkedinCtrl.text = sa['linkedin'] ?? '';
        _facebookCtrl.text = sa['facebook'] ?? '';
        _websiteCtrl.text = card.contact!.website ?? '';
        _otherCtrl.text = card.contact!.other ?? '';
      }
      if (card.privacy != null) {
        _visibility = card.privacy!.visibilityLevel;
      }
      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _handle(Map<String, dynamic> cp, String key) {
    final v = cp[key];
    if (v == null) return '';
    if (v is Map) return v['handle'] ?? '';
    return v.toString();
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

      Map<String, dynamic> cp = {};
      void addPref(String key, TextEditingController ctrl) {
        if (ctrl.text.trim().isNotEmpty) {
          cp[key] = {'handle': ctrl.text.trim(), 'preferred': false};
        }
      }
      addPref('whatsapp', _whatsappCtrl);
      addPref('telegram', _telegramCtrl);
      addPref('signal', _signalCtrl);
      addPref('instagram', _instagramCtrl);
      addPref('twitter_x', _twitterCtrl);
      addPref('threads', _threadsCtrl);
      addPref('bluesky', _bskyCtrl);
      addPref('mastodon', _mastodonCtrl);

      final sa = <String, dynamic>{};
      if (_linkedinCtrl.text.trim().isNotEmpty) sa['linkedin'] = _linkedinCtrl.text.trim();
      if (_facebookCtrl.text.trim().isNotEmpty) sa['facebook'] = _facebookCtrl.text.trim();

      final contactJson = ContactStatement.buildJson(
        iJson: delegateJson,
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        emails: _emailCtrl.text.trim().isNotEmpty
            ? [{'address': _emailCtrl.text.trim(), 'preferred': true}]
            : [],
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        contactPrefs: cp,
        socialAccounts: sa,
        website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
        other: _otherCtrl.text.trim().isNotEmpty ? _otherCtrl.text.trim() : null,
      );

      if (mounted) {
        final ok = await LgtmDialog.check(contactJson, context, title: 'About to sign contact card');
        if (!ok) { setState(() { _savingContact = false; }); return; }
      }

      final writer = HabloStatementWriter<ContactStatement>(habloFirestore, kHabloContactCollection);
      await writer.push(contactJson, signer);
      log('ContactStatement saved: ${const JsonEncoder.withIndent("  ").convert(contactJson)}', name: 'hablotengo');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact info saved!')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
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

      final writer = HabloStatementWriter<PrivacyStatement>(habloFirestore, kHabloPrivacyCollection);
      await writer.push(privacyJson, signer);
      log('PrivacyStatement saved: ${const JsonEncoder.withIndent("  ").convert(privacyJson)}', name: 'hablotengo');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visibility saved!')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _savingPrivacy = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('My Card')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (!signInState.canWrite)
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.all(8),
                child: const Text('Read-only mode — sign in with a delegate key to edit'),
              ),
            const SizedBox(height: 8),
            _buildField('Name', _nameCtrl, hint: 'Your display name'),
            _buildField('Email', _emailCtrl, hint: 'Preferred email address'),
            _buildField('Phone', _phoneCtrl, hint: '+1 555 555 5555'),
            const SizedBox(height: 16),
            const Text('Messaging', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            _buildField('WhatsApp', _whatsappCtrl, hint: '+1 555 555 5555'),
            _buildField('Telegram', _telegramCtrl, hint: '@username'),
            _buildField('Signal', _signalCtrl, hint: '+1 555 555 5555'),
            _buildField('Instagram', _instagramCtrl, hint: '@username'),
            _buildField('Twitter/X', _twitterCtrl, hint: '@username'),
            _buildField('Threads', _threadsCtrl, hint: '@username'),
            _buildField('Bluesky', _bskyCtrl, hint: 'user.bsky.social'),
            _buildField('Mastodon', _mastodonCtrl, hint: '@user@instance.social'),
            const SizedBox(height: 16),
            const Text('Social', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            _buildField('LinkedIn', _linkedinCtrl, hint: 'username'),
            _buildField('Facebook', _facebookCtrl, hint: 'username'),
            _buildField('Website', _websiteCtrl, hint: 'https://'),
            _buildField('Other', _otherCtrl, hint: 'Any other contact info', maxLines: 3),
            const SizedBox(height: 32),
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
            const Text('Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text(
              'Who can see your card details',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            ...VisibilityLevel.values.map((level) => RadioListTile<VisibilityLevel>(
                  title: Text(level.name),
                  subtitle: Text(_visibilityDesc(level)),
                  value: level,
                  groupValue: _visibility,
                  onChanged: (v) => setState(() => _visibility = v!),
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
            if (!signInState.canWrite)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sign in with a delegate key to save',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        enabled: signInState.canWrite,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  String _visibilityDesc(VisibilityLevel level) {
    switch (level) {
      case VisibilityLevel.permissive:
        return 'Anyone in your trust graph (1 path at any distance)';
      case VisibilityLevel.standard:
        return '1 path at distance ≤2, 2 independent paths at distance 3+';
      case VisibilityLevel.strict:
        return '2 paths at distance 2–3, 3 paths at distance 4+';
    }
  }
}
