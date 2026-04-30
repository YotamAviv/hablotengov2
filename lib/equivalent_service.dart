import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
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

/// Returns { token: disabledBy? } for each token in [tokens].
Future<Map<String, String?>> getEquivalentStatus(List<String> tokens, bool emulator) async {
  final response = await http.post(
    Uri.parse(habloGetEquivalentStatusUrl(emulator)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'tokens': tokens}),
  );
  if (response.statusCode != 200) {
    throw Exception('getEquivalentStatus failed: ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return json.map((tok, v) => MapEntry(tok, (v as Map<String, dynamic>)['disabledBy'] as String?));
}

Future<void> disableEquivalent(String equivalentToken, {required bool mergeContact, required bool emulator}) async {
  final response = await http.post(
    Uri.parse(habloDisableEquivalentUrl(emulator)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'equivalentToken': equivalentToken, 'mergeContact': mergeContact}),
  );
  if (response.statusCode != 200) {
    throw Exception('disableEquivalent failed: ${response.statusCode} ${response.body}');
  }
  debugPrint('disableEquivalent: $equivalentToken mergeContact=$mergeContact');
}

Future<void> enableAccount(bool emulator) async {
  final response = await http.post(
    Uri.parse(habloEnableAccountUrl(emulator)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(_authPayload()),
  );
  if (response.statusCode != 200) {
    throw Exception('enableAccount failed: ${response.statusCode} ${response.body}');
  }
  debugPrint('enableAccount: success');
}

Future<void> dismissEquivalent(String equivalentToken, bool emulator) async {
  final response = await http.post(
    Uri.parse(habloDismissEquivalentUrl(emulator)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({..._authPayload(), 'equivalentToken': equivalentToken}),
  );
  if (response.statusCode != 200) {
    throw Exception('dismissEquivalent failed: ${response.statusCode} ${response.body}');
  }
  debugPrint('dismissEquivalent: $equivalentToken');
}
