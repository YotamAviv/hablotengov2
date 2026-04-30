// Headless demo data generator.
// Writes Simpsons contact data via the setMyContact CF (demo auth).
//
// Run via: bin/createSimpsonsContactData.sh
// Requires: hablotengo emulator running (Functions 5003)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/dev/simpsons_public_keys.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WidgetRunner(scenario: _run));
}

Future<void> _run() async {
  for (final character in _simpsons) {
    await _writeContact(character);
  }
  // ignore: avoid_print
  print('PASS');
}

Future<void> _writeContact(_Character c) async {
  final identity = (kSimpsonsPublicKeys[c.keyName]! as Map).cast<String, dynamic>();
  final contact = {
    'name': c.name,
    if (c.notes != null) 'notes': c.notes,
    'entries': c.entries
        .map((e) => {
              'tech': e.tech,
              'value': e.value,
              if (e.preferred) 'preferred': true,
            })
        .toList(),
  };

  final response = await http.post(
    Uri.parse(habloSetMyContactUrl(true)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identity': identity, 'demo': true, 'contact': contact}),
  );

  if (response.statusCode != 200) {
    throw Exception('setMyContact failed for ${c.name}: ${response.statusCode} ${response.body}');
  }

  // ignore: avoid_print
  print('${c.name}: OK');
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
  _Character('Luann Van Houten',
      keyName: 'luann',
      notes: "Milhouse gets me on weekdays.",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-LUANN', preferred: true),
        ContactEntry(tech: 'email', value: 'luann@springfield.net'),
      ]),
  _Character('Nelson Muntz',
      keyName: 'nelson',
      notes: 'Ha-HA!',
      entries: [
        ContactEntry(tech: 'email', value: 'nelson@springfield-elementary.edu'),
        ContactEntry(tech: 'instagram', value: '@ha_haa_muntz'),
      ]),
  _Character('Lenny Leonard',
      keyName: 'lenny',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-LENNY', preferred: true),
        ContactEntry(tech: 'email', value: 'lenny@springfield-nuclear.gov'),
        ContactEntry(tech: 'signal', value: 'lenny.l'),
      ]),
  _Character('Carl Carlson',
      keyName: 'carl',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-CARL', preferred: true),
        ContactEntry(tech: 'email', value: 'carl@springfield-nuclear.gov'),
      ]),
  _Character('C. Montgomery Burns',
      keyName: 'burns',
      notes: 'Contact through Smithers only. Do NOT call after 9 PM.',
      entries: [
        ContactEntry(tech: 'email', value: 'burns@springfield-nuclear.gov'),
        ContactEntry(tech: 'fax', value: '+1-555-BRNSFX'),
      ]),
  _Character('Waylon Smithers',
      keyName: 'smithers',
      notes: "If it's about Mr. Burns, I'm already on it.",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-SMTHS', preferred: true),
        ContactEntry(tech: 'email', value: 'smithers@springfield-nuclear.gov'),
      ]),
  _Character('Krusty the Clown',
      keyName: 'krusty',
      notes: 'For bookings contact my agent.',
      entries: [
        ContactEntry(tech: 'email', value: 'krusty@krustybrand.com', preferred: true),
        ContactEntry(tech: 'fax', value: '+1-555-KRUST'),
        ContactEntry(tech: 'tiktok', value: '@therealKrustyKlown'),
      ]),
  _Character('Sideshow Bob',
      keyName: 'sideshow',
      notes: 'Do NOT leave me a voicemail about rakes.',
      entries: [
        ContactEntry(tech: 'email', value: 'r.terwilliger@springfield-arts.org', preferred: true),
        ContactEntry(tech: 'phone', value: '+1-555-TBOB'),
      ]),
  _Character('Seymour Skinner',
      keyName: 'seymore',
      notes: 'Mother screens my calls before 8 AM.',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-SKNNR', preferred: true),
        ContactEntry(tech: 'email', value: 'principal@springfield-elementary.edu'),
        ContactEntry(tech: 'email', value: 'armin.tanzarian@gmail.com'),
      ]),
];
