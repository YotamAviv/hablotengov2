import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/jsonish.dart';

import 'constants.dart';
import 'hablo_channel.dart';
import 'models/contact_statement.dart';
import 'sign_in_state.dart';

class ContactAccessDeniedException implements Exception {
  const ContactAccessDeniedException();
}

enum ContactStatus { found, denied, notFound }

class ContactResult {
  final ContactStatus status;
  final ContactData? contact;
  final bool someHidden;
  final String defaultStrictness;
  const ContactResult({required this.status, this.contact, this.someHidden = false, this.defaultStrictness = 'standard'});
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

// Per-delegate channel cache. Key: delegateToken.
final Map<String, HabloChannel> _channels = {};

HabloChannel _getChannel(bool emulator) {
  final delegateToken = getToken(signInState.delegatePublicKeyJson!);
  return _channels.putIfAbsent(
    delegateToken,
    () => HabloChannel(habloFunctionsBaseUrl(emulator), signInState),
  );
}

void resetChannels() => _channels.clear();

// ── Read operations (unchanged) ──────────────────────────────────────────────

Future<ContactData?> getMyContact(bool emulator) async {
  final url = Uri.parse(habloGetMyContactUrl(emulator));
  debugPrint('getMyContact: $url');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(_authPayload()),
  );
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw Exception('getMyContact failed: ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return ContactData.fromJson(json);
}

Future<ContactData?> getContact(String targetToken, bool emulator) async {
  final url = Uri.parse(habloGetContactUrl(emulator));
  debugPrint('getContact: $url targetToken=$targetToken');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'targetToken': targetToken}),
  );
  if (response.statusCode == 404) return null;
  if (response.statusCode == 403) throw const ContactAccessDeniedException();
  if (response.statusCode != 200) {
    throw Exception('getContact failed: ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return ContactData.fromJson(json);
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
    return MapEntry(token, ContactResult(status: status, contact: contact, someHidden: someHidden, defaultStrictness: defaultStrictness));
  });
}

// ── Write operations ─────────────────────────────────────────────────────────

/// Saves [newContact], diffing against [oldContact] to emit only changed statements.
Future<void> setMyContact(ContactData newContact, bool emulator, {ContactData? oldContact}) async {
  await _setMyContactSigned(oldContact, newContact, emulator);
}

Future<void> _setMyContactSigned(
    ContactData? oldContact, ContactData newContact, bool emulator) async {
  final channel = _getChannel(emulator);
  final signer = signInState.signer!;
  final delegatePk = signInState.delegatePublicKeyJson!;
  final identityToken = signInState.identityToken!;

  // Name
  if (oldContact?.name != newContact.name) {
    await channel.push(
      buildSetFieldJson(field: 'name', value: newContact.name, delegatePublicKeyJson: delegatePk, identityToken: identityToken),
      signer,
    );
  }

  // Notes
  if (oldContact?.notes != newContact.notes) {
    await channel.push(
      buildSetFieldJson(field: 'notes', value: newContact.notes, delegatePublicKeyJson: delegatePk, identityToken: identityToken),
      signer,
    );
  }

  final Map<double, ContactEntry> oldByOrder = {
    for (final e in oldContact?.entries ?? []) e.order: e,
  };
  final Map<double, ContactEntry> newByOrder = {
    for (final e in newContact.entries) e.order: e,
  };

  // Deleted entries
  for (final order in oldByOrder.keys) {
    if (!newByOrder.containsKey(order)) {
      await channel.push(
        buildClearEntryJson(order: order, delegatePublicKeyJson: delegatePk, identityToken: identityToken),
        signer,
      );
    }
  }

  // New or changed entries
  for (final entry in newContact.entries) {
    final old = oldByOrder[entry.order];
    if (old == null ||
        old.tech != entry.tech ||
        old.value != entry.value ||
        old.preferred != entry.preferred ||
        old.visibility != entry.visibility) {
      await channel.push(
        buildSetEntryJson(entry: entry, delegatePublicKeyJson: delegatePk, identityToken: identityToken),
        signer,
      );
    }
  }

  debugPrint('_setMyContactSigned: done');
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
