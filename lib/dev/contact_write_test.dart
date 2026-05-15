// Integration test: setMyContact and setSettingsField preserve each other's data.
//
// Prerequisites:
//   - Hablo emulator running from golden export: bin/start_emulator.sh
//   - OneOfUs emulator running: oneofusv22/bin/start_emulator.sh
//   - lib/dev/simpsons_private_keys.dart generated: python3 bin/gen_simpsons_private_keys_dart.py
//
// Run via:
//   python3 bin/chrome_widget_runner.py -t lib/dev/contact_write_test.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/contact_service.dart';
import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/hablo_statement.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/dev/simpsons_private_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  HabloStatement.init();

  channelFactory = ChannelFactory(FireChoice.emulator);
  channelFactory.register(
    exportUrl: habloExportUrl(false),
    functionsUrl: habloFunctionsBaseUrl(false),
    emulatorExportUrl: habloExportUrl(true),
    emulatorFunctionsUrl: habloFunctionsBaseUrl(true),
    writeEndpoint: 'write',
    writeAuthHook: () => signInState.authPayload()!,
    readAuthHook: () => signInState.authPayload()!,
  );

  runApp(WidgetRunner(scenario: _runTest));
}

Future<void> _runTest() async {
  // Sign in as Homer (demo) using his existing golden-export hablo delegate.
  // Using homer-hablo0 writes to the canonical stream, not a new one.
  final identityData = kSimpsonsPrivateKeys['homer']! as Map;
  final identityKeyPair = await crypto.parseKeyPair(
    ((identityData['keyPair'] as Map).cast<String, dynamic>()),
  );
  final identityPubKeyJson = await (await identityKeyPair.publicKey).json;

  final delegateData = kSimpsonsPrivateKeys['homer-hablo0']! as Map;
  final delegateKeyPair = await crypto.parseKeyPair(
    ((delegateData['keyPair'] as Map).cast<String, dynamic>()),
  );

  await signInState.signInDemoWithDelegate(identityPubKeyJson, delegateKeyPair);

  // 1. Save contact info.
  final contact = ContactData(
    name: 'Homer Simpson',
    notes: 'Test notes xyz',
    entries: [
      const ContactEntry(tech: 'email', value: 'homer@test.com', preferred: true),
    ],
  );
  await setMyContact(contact, true);

  // 2. Read back — verify contact.
  var result = await getMyContact(true);
  _assert(result.contact?.name == 'Homer Simpson',
      'save contact: name="${result.contact?.name}"');
  _assert(result.contact?.notes == 'Test notes xyz',
      'save contact: notes="${result.contact?.notes}"');
  _assert(result.contact?.entries.length == 1,
      'save contact: entries=${result.contact?.entries.length}');

  // 3. Save a setting.
  await setSettingsField('defaultStrictness', 'strict', true);

  // 4. Read back — contact must still be present after settings save.
  result = await getMyContact(true);
  _assert(result.contact?.name == 'Homer Simpson',
      'settings save wiped name: "${result.contact?.name}"');
  _assert(result.contact?.entries.length == 1,
      'settings save wiped entries: ${result.contact?.entries.length}');
  _assert(result.rawStatement?['set']?['defaultStrictness'] == 'strict',
      'settings not saved: ${result.rawStatement?['set']}');

  // 5. Save updated contact.
  final updated = ContactData(
    name: 'Homer J. Simpson',
    entries: [
      const ContactEntry(tech: 'email', value: 'homer@updated.com', preferred: true),
      const ContactEntry(tech: 'phone', value: '+1-555-HOMER'),
    ],
  );
  await setMyContact(updated, true);

  // 6. Read back — settings must still be present after contact save.
  result = await getMyContact(true);
  _assert(result.contact?.name == 'Homer J. Simpson',
      'contact update: name="${result.contact?.name}"');
  _assert(result.contact?.entries.length == 2,
      'contact update: entries=${result.contact?.entries.length}');
  _assert(result.rawStatement?['set']?['defaultStrictness'] == 'strict',
      'contact save wiped settings: ${result.rawStatement?['set']}');

  // 7. Restore original demo contact so other tests see clean data.
  await setMyContact(
    const ContactData(
      name: 'Homer Simpson',
      notes: 'Never call me',
      entries: [
        ContactEntry(tech: 'phone', value: '+1-555-HOMER', preferred: true),
        ContactEntry(tech: 'email', value: 'homer@springfield-nuclear.gov'),
      ],
    ),
    true,
  );

  // ignore: avoid_print
  print('PASS');
}

void _assert(bool condition, String message) {
  if (!condition) {
    // ignore: avoid_print
    print('FAIL: $message');
    throw Exception(message);
  }
}
