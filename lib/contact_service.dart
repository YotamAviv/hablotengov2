import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement_source.dart';

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
  const ContactResult({required this.status, this.contact, this.someHidden = false, this.defaultStrictness = 'standard', this.rawStatement});
}

class MyContactResult {
  final ContactData? contact;
  final Json? rawStatement;
  const MyContactResult({this.contact, this.rawStatement});
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

Future<StatementChannel<HabloStatement>> _channel() async {
  final delegateToken = getToken(signInState.delegatePublicKeyJson!);
  final streamId = '${delegateToken}_${signInState.identityToken!}';
  debugPrint('contact_service: writing to stream=$streamId');
  final channel = channelFactory.getChannel<HabloStatement>(kHabloDomain, streamId);
  await channel.fetch({delegateToken: null});
  return channel;
}

// ── Read operations ──────────────────────────────────────────────────────────

Future<MyContactResult> getMyContact(bool emulator) async {
  if (signInState.identityJson == null) {
    throw StateError('getMyContact called without a signed-in identity');
  }
  final url = Uri.parse(habloGetMyContactUrl(emulator));
  debugPrint('getMyContact: $url');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(_authPayload()),
  );
  if (response.statusCode == 404) {
    return const MyContactResult();
  }
  if (response.statusCode != 200) {
    throw Exception('getMyContact failed: ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>?;
  if (json == null) return const MyContactResult();
  final setMap = json['set'] as Map<String, dynamic>?;
  return MyContactResult(
    contact: setMap != null && setMap.isNotEmpty ? ContactData.fromJson(setMap) : null,
    rawStatement: json,
  );
}



Future<Map<String, ContactResult>> getBatchContacts(List<String> targetTokens, bool emulator) async {
  final url = Uri.parse(habloGetBatchContactsUrl(emulator));
  debugPrint('getBatchContacts: $url count=${targetTokens.length}');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'targetTokens': targetTokens}),
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
    return MapEntry(token, ContactResult(status: status, contact: contact, someHidden: someHidden, defaultStrictness: defaultStrictness, rawStatement: rawStatement));
  });
}

// ── Write operations ─────────────────────────────────────────────────────────

Future<void> setMyContact(ContactData contact, bool emulator) async {
  final current = await getMyContact(emulator);
  debugPrint('setMyContact: current rawStatement=${jsonEncode(current.rawStatement)}');
  final currentSet = Map<String, dynamic>.from(
    (current.rawStatement?['set'] as Map<String, dynamic>?) ?? {},
  );
  currentSet['name'] = contact.name;
  if (contact.notes != null) {
    currentSet['notes'] = contact.notes;
  } else {
    currentSet.remove('notes');
  }
  currentSet['entries'] = contact.entries.map((e) => e.toJson()).toList();

  final channel = await _channel();
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;
  final stmt = buildFullSetJson(set: currentSet, delegatePublicKeyJson: delegatePk, identityToken: identityToken);
  debugPrint('setMyContact: pushing set=${jsonEncode(currentSet)}');
  await channel.push(stmt, signInState.signer!);
  debugPrint('setMyContact: done');
}

Future<void> setSettingsField(String field, dynamic value, bool emulator) async {
  final current = await getMyContact(emulator);
  debugPrint('setSettingsField: $field=$value current rawStatement=${jsonEncode(current.rawStatement)}');
  final currentSet = Map<String, dynamic>.from(
    (current.rawStatement?['set'] as Map<String, dynamic>?) ?? {},
  );
  currentSet[field] = value;

  final channel = await _channel();
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;
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
