import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:oneofus_common/trust_statement.dart';

import 'app.dart';
import 'constants.dart';
import 'firebase_options.dart'; // gitignored; regenerate with: flutterfire configure
import 'key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TrustStatement.init();

  // TODO: restore URL-based switching when deploying to prod.
  const bool emulator = true;

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  // $ ./bin/start_emulator.sh  (Firestore 8082, Functions 5003)
  firestore.useFirestoreEmulator('localhost', kHabloFirestoreEmulatorPort);

  startKeyStorageCoordinator();
  await tryRestoreKeys();

  runApp(HabloApp(firestore: firestore, emulator: emulator));
}
