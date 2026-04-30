import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'models/contact_statement.dart';
import 'sign_in_state.dart';

class ContactAccessDeniedException implements Exception {
  const ContactAccessDeniedException();
}

enum ContactStatus { found, denied, notFound }

class ContactResult {
  final ContactStatus status;
  final ContactData? contact;
  const ContactResult({required this.status, this.contact});
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
    return MapEntry(token, ContactResult(status: status, contact: contact));
  });
}

Future<void> setMyContact(ContactData contact, bool emulator) async {
  final url = Uri.parse(habloSetMyContactUrl(emulator));
  debugPrint('setMyContact: $url');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'contact': contact.toJson()}),
  );
  if (response.statusCode != 200) {
    throw Exception('setMyContact failed: ${response.statusCode} ${response.body}');
  }
}
