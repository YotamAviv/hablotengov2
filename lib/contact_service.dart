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
    return {'identity': signInState.identityJson!, 'demo': true};
  }
  return {
    'identity': signInState.identityJson!,
    'sessionTime': signInState.sessionTime!,
    'sessionSignature': signInState.sessionSignature!,
  };
}


Future<Map<String, ContactResult>> getBatchContacts(List<String> targetTokens, bool emulator, {bool withDelegateStatement = false}) async {
  final url = Uri.parse(habloGetBatchContactsUrl(emulator));
  debugPrint('getBatchContacts: $url count=${targetTokens.length}');
  final body = <String, dynamic>{
    ..._authPayload(),
    'targetTokens': targetTokens,
    if (withDelegateStatement && signInState.delegatePublicKeyJson != null)
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
  return json.map((token, value) {
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
}

// ── Write operations ─────────────────────────────────────────────────────────

Future<void> setMyContact(ContactData contact, bool emulator,
    {String? defaultStrictness, Json? rawStatement, Json? delegateStatement}) async {
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;
  final delegateToken = getToken(delegatePk);
  final streamId = '${delegateToken}_$identityToken';
  final channel = channelFactory.getChannel<HabloStatement>(kHabloExportUrl, streamId);

  if (!channel.isCached(delegateToken)) {
    if (delegateStatement != null) {
      channel.seed(delegateToken, [HabloStatement(Jsonish(delegateStatement))]);
    } else {
      channel.seed(delegateToken, []);
    }
  }

  final currentSet = Map<String, dynamic>.from(
    (rawStatement?['set'] as Map<String, dynamic>?) ?? {},
  );
  currentSet['name'] = contact.name;
  if (contact.notes != null) {
    currentSet['notes'] = contact.notes;
  } else {
    currentSet.remove('notes');
  }
  currentSet['entries'] = contact.entries.map((e) => e.toJson()).toList();
  if (defaultStrictness != null) currentSet['defaultStrictness'] = defaultStrictness;

  final stmt = buildFullSetJson(set: currentSet, delegatePublicKeyJson: delegatePk, identityToken: identityToken);
  debugPrint('setMyContact: pushing set=${jsonEncode(currentSet)}');
  await channel.push(stmt, signInState.signer!);
  debugPrint('setMyContact: done');
}

Future<void> setSettingsField(String field, dynamic value, bool emulator) async {
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;
  final delegateToken = getToken(delegatePk);

  final loaded = await getBatchContacts([identityToken], emulator, withDelegateStatement: true);
  final current = loaded[identityToken];
  debugPrint('setSettingsField: $field=$value current rawStatement=${jsonEncode(current?.rawStatement)}');

  final currentSet = Map<String, dynamic>.from(
    (current?.rawStatement?['set'] as Map<String, dynamic>?) ?? {},
  );
  currentSet[field] = value;

  final streamId = '${delegateToken}_$identityToken';
  final channel = channelFactory.getChannel<HabloStatement>(kHabloExportUrl, streamId);
  if (!channel.isCached(delegateToken)) {
    final delegateStatement = current?.delegateStatement;
    if (delegateStatement != null) {
      channel.seed(delegateToken, [HabloStatement(Jsonish(delegateStatement))]);
    } else {
      channel.seed(delegateToken, []);
    }
  }
  final stmt = buildFullSetJson(set: currentSet, delegatePublicKeyJson: delegatePk, identityToken: identityToken);
  debugPrint('setSettingsField: pushing set=${jsonEncode(currentSet)}');
  await channel.push(stmt, signInState.signer!);
  debugPrint('setSettingsField: done');
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
