import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/jsonish.dart';

import 'constants.dart';
import 'models/contact_statement.dart';
import 'models/hablo_statement.dart';
import 'sign_in_state.dart';

enum ContactStatus { found, denied, notFound }

class ContactResult {
  final ContactStatus status;
  final ContactData? contact;
  final bool someHidden;
  final String defaultStrictness;
  final Json? rawStatement;
  final Json? delegateStatement;
  const ContactResult({required this.status, this.contact, this.someHidden = false, this.defaultStrictness = 'standard', this.rawStatement, this.delegateStatement});
}

Map<String, dynamic> _authPayload() {
  if (signInState.isDemo) {
    return {'identity': signInState.identityJson!};
  }
  return {
    'identity': signInState.identityJson!,
    'sessionTime': signInState.sessionTime!,
    'sessionSignature': signInState.sessionSignature!,
  };
}


Future<Map<String, ContactResult>> getBatchContacts(List<String> targetTokens, bool emulator) async {
  final url = Uri.parse(habloGetBatchContactsUrl(emulator));
  debugPrint('getBatchContacts: $url count=${targetTokens.length}');
  final body = <String, dynamic>{
    ..._authPayload(),
    'targetTokens': targetTokens,
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
  final results = json.map((token, value) {
    final v = value as Map<String, dynamic>;
    final status = switch (v['status'] as String) {
      'found'     => ContactStatus.found,
      'denied'    => ContactStatus.denied,
      _           => ContactStatus.notFound,
    };
    final contact = status == ContactStatus.found
        ? ContactData.fromJson(v['contact'] as Map<String, dynamic>)
        : null;
    final someHidden = v['someHidden'] == true;
    final defaultStrictness = v['defaultStrictness'] as String? ?? 'standard';
    final rawStatement = v['rawStatement'] as Json?;
    final delegateStatement = v['delegateStatement'] as Json?;
    return MapEntry(token, ContactResult(status: status, contact: contact, someHidden: someHidden, defaultStrictness: defaultStrictness, rawStatement: rawStatement, delegateStatement: delegateStatement));
  });
  if (signInState.delegatePublicKeyJson != null) {
    final selfToken = signInState.identityToken;
    if (selfToken != null && results.containsKey(selfToken)) {
      final delegatePk = signInState.delegatePublicKeyJson!;
      final identityToken = signInState.identityToken!;
      final delegateToken = getToken(delegatePk);
      final streamId = '${delegateToken}_$identityToken';
      final channel = channelFactory.getChannel<HabloStatement>(kHabloExportUrl, streamId);
      if (channel.isCached(delegateToken)) await channel.clear();
      final delegateStatement = results[selfToken]!.delegateStatement;
      channel.seed(delegateToken,
          delegateStatement != null ? [HabloStatement(Jsonish(delegateStatement))] : []);
    }
  }
  return results;
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


Future<void> deleteAccount(bool emulator) async {
  final url = Uri.parse(habloDeleteAccountUrl(emulator));
  debugPrint('deleteAccount: $url');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(_authPayload()),
  );
  if (response.statusCode != 200) {
    throw Exception('deleteAccount failed: ${response.statusCode} ${response.body}');
  }
}
