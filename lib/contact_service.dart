import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'models/contact_statement.dart';
import 'sign_in_state.dart';

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
