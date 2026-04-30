import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'sign_in_state.dart';
import 'dev/simpsons_public_keys.dart';

List<String> get kSimpsonsKeyNames => kSimpsonsPublicKeys.keys
    .where((k) => !k.contains('-'))
    .toList();

Future<void> demoSignIn(String keyName, bool emulator) async {
  final jwk = (kSimpsonsPublicKeys[keyName]! as Map).cast<String, dynamic>();
  final url = Uri.parse(habloDemoSignInUrl(emulator));
  debugPrint('demoSignIn: signing in as $keyName via $url');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identity': jwk}),
  );

  if (response.statusCode != 200) {
    throw Exception('demoSignIn failed: ${response.statusCode} ${response.body}');
  }

  debugPrint('demoSignIn: success for $keyName');
  signInState.restoreDemoKeys(jwk);
}
