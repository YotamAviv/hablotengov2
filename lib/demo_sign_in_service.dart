import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'sign_in_state.dart';
import 'dev/simpsons_public_keys.dart';

const Map<String, String> kSimpsonsDisplayNames = {
  'lisa': 'Lisa',
  'bart': 'Bart',
  'homer': 'Homer',
  'marge': 'Marge',
  'maggie': 'Maggie',
  'milhouse': 'Milhouse',
  'luann': 'Luann',
  'ralph': 'Ralph',
  'nelson': 'Nelson',
  'lenny': 'Lenny',
  'carl': 'Carl',
  'burns': 'Mr. Burns',
  'smithers': 'Smithers',
  'krusty': 'Krusty',
  'sideshow': 'Sideshow Bob',
  'mel': 'Sideshow Mel',
  'seymore': 'Seymour',
  'amanda': 'Amanda',
};

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
