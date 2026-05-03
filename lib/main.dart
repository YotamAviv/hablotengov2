import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:oneofus_common/trust_statement.dart';

import 'app.dart';
import 'constants.dart';
import 'firebase_options.dart'; // gitignored; regenerate with: flutterfire configure
import 'key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TrustStatement.init();

  final String? fireParam = kIsWeb ? Uri.base.queryParameters['fire'] : null;
  final bool emulator = kIsWeb && Uri.base.host == 'localhost' && fireParam != 'prod';
  final bool demoMode = kIsWeb && Uri.base.queryParameters['demo'] == 'true';
  final String? startupTarget = kIsWeb ? Uri.base.queryParameters['target'] : null;
  debugPrint('main: Uri.base=${Uri.base} emulator=$emulator demoMode=$demoMode startupTarget=$startupTarget');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  if (emulator) {
    firestore.useFirestoreEmulator('localhost', kHabloFirestoreEmulatorPort);
  }

  startKeyStorageCoordinator();
  await tryRestoreKeys();

  runApp(HabloApp(firestore: firestore, emulator: emulator, demoMode: demoMode, startupTarget: startupTarget));
}
