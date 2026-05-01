// Headless demo data generator — production.
// Writes Simpsons contact data via the setMyContact CF (production auth).
//
// Run via: bin/createSimpsonsContactData_prod.sh

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
  final Map<String, dynamic> identity = (kSimpsonsPublicKeys[c.keyName]! as Map).cast<String, dynamic>();
  final Map<String, dynamic> contact = {
    'name': c.displayName,
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
    Uri.parse(habloSetMyContactUrl(false)),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identity': identity, 'demo': true, 'contact': contact}),
  );

  if (response.statusCode != 200) {
    throw Exception('setMyContact failed for ${c.keyName}: ${response.statusCode} ${response.body}');
  }

  // ignore: avoid_print
  print('${c.keyName}: OK');
}

class _Character {
  final String keyName;
  final String displayName;
  final String? notes;
  final List<ContactEntry> entries;
  const _Character(this.keyName, {required this.displayName, this.notes, this.entries = const []});
}

const List<_Character> _simpsons = [
  _Character('homer',
      displayName: 'Homer Simpson',
      notes: "Never call me",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-HOMER', preferred: true),
        ContactEntry(tech: 'email', value: 'homer@springfield-nuclear.gov'),
      ]),
  _Character('marge',
      displayName: 'Marge Simpson',
      notes: "Call me!!!",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-MARGE', preferred: true),
        ContactEntry(tech: 'email', value: 'marge@simpsons.com'),
      ]),
  _Character('bart',
      displayName: 'Bart Simpson',
      notes: 'Eat my shorts.',
      entries: [
        ContactEntry(tech: 'email', value: 'bart@springfield-elementary.edu'),
        ContactEntry(tech: 'instagram', value: '@thrillhouse_bart'),
      ]),
  _Character('lisa',
      displayName: 'Lisa Simpson',
      entries: [
        ContactEntry(tech: 'email', value: 'lisa@simpsons.com', preferred: true),
        ContactEntry(tech: 'phone', value: '+1-555-LISA'),
      ]),
  _Character('maggie', displayName: 'Maggie Simpson'),
  _Character('milhouse',
      displayName: 'Milhouse Van Houten',
      entries: [
        ContactEntry(tech: 'email', value: 'milhouse@springfield-elementary.edu'),
      ]),
  _Character('luann',
      displayName: 'Luann Van Houten',
      notes: "Milhouse gets me on weekdays.",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-LUANN', preferred: true),
        ContactEntry(tech: 'email', value: 'luann@springfield.net'),
      ]),
  _Character('nelson',
      displayName: 'Nelson Muntz',
      notes: 'Ha-HA!',
      entries: [
        ContactEntry(tech: 'email', value: 'nelson@springfield-elementary.edu'),
        ContactEntry(tech: 'instagram', value: '@ha_haa_muntz'),
      ]),
  _Character('lenny',
      displayName: 'Lenny Leonard',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-LENNY', preferred: true),
        ContactEntry(tech: 'email', value: 'lenny@springfield-nuclear.gov'),
        ContactEntry(tech: 'signal', value: 'lenny.l'),
      ]),
  _Character('carl',
      displayName: 'Carl Carlson',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-CARL', preferred: true),
        ContactEntry(tech: 'email', value: 'carl@springfield-nuclear.gov'),
      ]),
  _Character('burns',
      displayName: 'C. Montgomery Burns',
      notes: 'Contact through Smithers only. Do NOT call after 9 PM.',
      entries: [
        ContactEntry(tech: 'email', value: 'burns@springfield-nuclear.gov'),
        ContactEntry(tech: 'fax', value: '+1-555-BRNSFX'),
      ]),
  _Character('smithers',
      displayName: 'Waylon Smithers',
      notes: "If it's about Mr. Burns, I'm already on it.",
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-SMTHS', preferred: true),
        ContactEntry(tech: 'email', value: 'smithers@springfield-nuclear.gov'),
      ]),
  _Character('krusty',
      displayName: 'Krusty the Clown',
      notes: 'For bookings contact my agent.',
      entries: [
        ContactEntry(tech: 'email', value: 'krusty@krustybrand.com', preferred: true),
        ContactEntry(tech: 'fax', value: '+1-555-KRUST'),
        ContactEntry(tech: 'tiktok', value: '@therealKrustyKlown'),
      ]),
  _Character('sideshow',
      displayName: 'Sideshow Bob',
      notes: 'Do NOT leave me a voicemail about rakes.',
      entries: [
        ContactEntry(tech: 'email', value: 'r.terwilliger@springfield-arts.org', preferred: true),
        ContactEntry(tech: 'phone', value: '+1-555-TBOB'),
      ]),
  _Character('seymore',
      displayName: 'Seymour Skinner',
      notes: 'Mother screens my calls before 8 AM.',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-SKNNR', preferred: true),
        ContactEntry(tech: 'email', value: 'principal@springfield-elementary.edu'),
        ContactEntry(tech: 'email', value: 'armin.tanzarian@gmail.com'),
      ]),
];
