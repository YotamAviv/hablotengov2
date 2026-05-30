import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';

import 'constants.dart';
import 'models/contact_statement.dart';
import 'models/hablo_statement.dart';
import 'sign_in_state.dart';

enum ContactStatus { found, denied, notFound }

class TrustContact {
  final String token;
  final String? label;
  final List<String> monikers;
  final Json? keyPayload;
  final ContactStatus status;
  final ContactData? contact;
  final bool someHidden;
  final String defaultStrictness;
  final Json? rawStatement;
  final Json? delegateStatement;

  const TrustContact({
    required this.token,
    required this.label,
    required this.monikers,
    required this.keyPayload,
    required this.status,
    this.contact,
    this.someHidden = false,
    this.defaultStrictness = 'standard',
    this.rawStatement,
    this.delegateStatement,
  });

  TrustContact withContact(ContactData updated) => TrustContact(
    token: token,
    label: label,
    monikers: monikers,
    keyPayload: keyPayload,
    status: status,
    contact: updated,
    someHidden: someHidden,
    defaultStrictness: updated.defaultStrictness,
    rawStatement: rawStatement,
    delegateStatement: delegateStatement,
  );
}

class ContactsData {
  final String selfToken;
  final List<TrustContact> contacts;
  final Map<String, TrustContact> byToken;

  ContactsData({required this.selfToken, required this.contacts})
      : byToken = {for (final c in contacts) c.token: c};
}

Future<Map<String, dynamic>> _authPayload() async {
  if (signInState.isDemo) {
    return {'identity': signInState.identityJson!};
  }
  return await signInState.requestCredential() ?? signInState.authPayload()!;
}

Future<ContactsData> getBatchContacts() async {
  final url = Uri.parse(habloGetBatchContactsUrl);
  debugPrint('getBatchContacts: $url');
  final body = <String, dynamic>{
    ...await _authPayload(),
    if (signInState.delegatePublicKeyJson != null)
      'currentDelegateToken': getToken(signInState.delegatePublicKeyJson!),
  };
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (response.statusCode != 200) {
    throw Exception('getBatchContacts failed: ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final selfToken = json['selfToken'] as String;
  final rawContacts = json['contacts'] as List<dynamic>;

  final contacts = rawContacts.map((v) {
    final c = v as Map<String, dynamic>;
    final token = c['token'] as String;
    final label = c['label'] as String?;
    final monikers = (c['monikers'] as List<dynamic>).cast<String>();
    final keyPayload = c['keyPayload'] as Json?;
    final status = switch (c['status'] as String) {
      'found'  => ContactStatus.found,
      'denied' => ContactStatus.denied,
      _        => ContactStatus.notFound,
    };
    final contact = (status == ContactStatus.found && c['contact'] != null)
        ? ContactData.fromJson(c['contact'] as Map<String, dynamic>)
        : null;
    final someHidden = c['someHidden'] == true;
    final defaultStrictness = c['defaultStrictness'] as String? ?? 'standard';
    final rawStatement = c['rawStatement'] as Json?;
    final delegateStatement = c['delegateStatement'] as Json?;

    // Register FedKey so Nerdster deep-link URLs can resolve the endpoint.
    if (keyPayload != null) FedKey.fromPayload(keyPayload);

    return TrustContact(
      token: token,
      label: label,
      monikers: monikers,
      keyPayload: keyPayload,
      status: status,
      contact: contact,
      someHidden: someHidden,
      defaultStrictness: defaultStrictness,
      rawStatement: rawStatement,
      delegateStatement: delegateStatement,
    );
  }).toList();

  final data = ContactsData(selfToken: selfToken, contacts: contacts);

  // Prime the write StatementChannel for the signed-in user's delegate stream.
  if (signInState.delegatePublicKeyJson != null) {
    final self = data.byToken[selfToken];
    if (self != null) {
      final delegatePk = signInState.delegatePublicKeyJson!;
      final delegateToken = getToken(delegatePk);
      final streamId = '${delegateToken}_$selfToken';
      final channel = channelFactory.getChannel<HabloStatement>(kHabloExportUrl, streamId);
      if (channel.isCached(delegateToken)) await channel.clear();
      channel.seed(delegateToken,
          self.delegateStatement != null ? [HabloStatement(Jsonish(self.delegateStatement!))] : []);
    }
  }

  return data;
}

// ── Write operations ─────────────────────────────────────────────────────────

// This project uses StatementChannel differently from the others (Nerdster, Oneofus) who's usage is more common (they read and write using these).
// Hablo is much more Cloud Functions based and never uses a StatementChannel to read.
// But it does use a single StatementChannel to write using the signed in user's delegate key.
// For this reason, after we use the Cloud Functions to fetch all the data (instead of reading
// using StatementChannels), we prime that single StatementChannel.
// Rep-invariant:
// - the write StatementChannel is always cached and ready. contacts_screen primes it as part of its one getBatchContacts call.
// - the app runs entirely optimistically and never has to load unless the user explicitly triggers a refresh.
// - On refresh we clear (and await) that StatementChannel, fetch everything again, and seed that StatementChannel.

Future<void> setMyContact(ContactData contact) async {
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;
  final delegateToken = getToken(delegatePk);
  final streamId = '${delegateToken}_$identityToken';
  final channel = channelFactory.getChannel<HabloStatement>(kHabloExportUrl, streamId);
  assert(channel.isCached(delegateToken), 'write channel must be primed before setMyContact');

  final set = <String, dynamic>{
    'name': contact.name,
    if (contact.notes != null) 'notes': contact.notes,
    'entries': contact.entries.map((e) => e.toJson()).toList(),
    'defaultStrictness': contact.defaultStrictness,
  };

  final stmt = buildFullSetJson(set: set, delegatePublicKeyJson: delegatePk, identityToken: identityToken);
  debugPrint('setMyContact: pushing set=${jsonEncode(set)}');
  await channel.push(stmt, signInState.signer!);
  debugPrint('setMyContact: done');
}


Future<void> deleteAccount() async {
  final url = Uri.parse(habloDeleteAccountUrl);
  debugPrint('deleteAccount: $url');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(await _authPayload()),
  );
  if (response.statusCode != 200) {
    throw Exception('deleteAccount failed: ${response.statusCode} ${response.body}');
  }
}
