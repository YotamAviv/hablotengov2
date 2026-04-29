// Web test: Lisa's trusted network resolves to correct names.
//
// Prerequisites:
//   - OneOfUs emulator running (oneofusv22/bin/start_emulator.sh) with Simpsons trust data
//
// Run via:
//   python3 bin/chrome_widget_runner.py -t lib/dev/contacts_web_test.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/dev/contacts_suite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }
  // OneOfUs emulator — Functions port 5002
  // (no Hablo Firebase needed; trust graph comes from OneOfUs export only)

  runApp(WidgetRunner(scenario: runContactsVerification));
}
