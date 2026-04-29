// Headless demo data generator.
// Writes Simpsons contact data to the hablotengo Firestore emulator.
//
// Run via: bin/createSimpsonsContactData.sh
// Requires: hablotengo emulator running (Firestore 8082, Functions 5003)
//
// TO RUN ON PROD: remove the useFirestoreEmulator call below.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/dev/simpsons_public_keys.dart';

const OouCryptoFactory _crypto = crypto;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  // EMULATOR ONLY — remove this line to run on prod:
  FirebaseFirestore.instance
      .useFirestoreEmulator('localhost', kHabloFirestoreEmulatorPort);

  runApp(WidgetRunner(scenario: _run));
}

Future<void> _run() async {
  final firestore = FirebaseFirestore.instance;

  for (final character in _simpsons) {
    await _writeContact(firestore, character);
  }

  // ignore: avoid_print
  print('PASS');
}

Future<void> _writeContact(FirebaseFirestore firestore, _Character c) async {
  final Json publicKeyJson =
      (kSimpsonsPublicKeys[c.keyName]! as Map).cast<String, dynamic>();
  final OouPublicKey publicKey = await _crypto.parsePublicKey(publicKeyJson);
  final String identityToken = getToken(await publicKey.json);

  final Map<String, dynamic> doc = {
    'name': c.name,
    if (c.notes != null) 'notes': c.notes,
    'entries': c.entries
        .map((e) => {
              'tech': e.tech,
              'value': e.value,
              if (e.preferred) 'preferred': true,
            })
        .toList(),
    'time': DateTime.now().toUtc().toIso8601String(),
  };

  await firestore.collection('contacts').doc(identityToken).set(doc);

  // ignore: avoid_print
  print('${c.name}: identityToken=$identityToken');
}

class _Character {
  final String name;
  final String keyName;
  final String? notes;
  final List<ContactEntry> entries;
  const _Character(this.name, {required this.keyName, this.notes, this.entries = const []});
}

const List<_Character> _simpsons = [
  _Character('Homer Simpson',
      keyName: 'homer',
      notes: "D'oh!",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-HOMER', preferred: true),
        ContactEntry(tech: 'email', value: 'homer@springfield-nuclear.gov'),
      ]),
  _Character('Marge Simpson',
      keyName: 'marge',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-MARGE', preferred: true),
        ContactEntry(tech: 'email', value: 'marge@simpsons.com'),
      ]),
  _Character('Bart Simpson',
      keyName: 'bart',
      notes: 'Eat my shorts.',
      entries: [
        ContactEntry(tech: 'email', value: 'bart@springfield-elementary.edu'),
        ContactEntry(tech: 'instagram', value: '@thrillhouse_bart'),
      ]),
  _Character('Lisa Simpson',
      keyName: 'lisa',
      entries: [
        ContactEntry(tech: 'email', value: 'lisa@simpsons.com', preferred: true),
        ContactEntry(tech: 'phone', value: '+1-555-LISA'),
      ]),
  _Character('Maggie Simpson', keyName: 'maggie'),
  _Character('Milhouse Van Houten',
      keyName: 'milhouse',
      entries: [
        ContactEntry(tech: 'email', value: 'milhouse@springfield-elementary.edu'),
      ]),
];
