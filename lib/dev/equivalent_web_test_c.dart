// Scenario C: Homer (old key) signs in — account not disabled.
//
// Prerequisites (fresh state):
//   ./bin/stop_emulator.sh && ./bin/start_emulator.sh && ./bin/createSimpsonsContactData.sh
//
// Run via:
//   python3 bin/chrome_widget_runner.py -t lib/dev/equivalent_web_test_c.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/dev/equivalent_suite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  runApp(WidgetRunner(scenario: () => runScenario(scenarioC)));
}
