import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/app.dart';
import 'package:hablotengo/dev/simpsons_demo.dart';
import 'package:hablotengo/fire_choice.dart';
import 'package:hablotengo/hablotengo_fire.dart';
import 'package:hablotengo/key_storage_coordinator.dart';
import 'package:hablotengo/key_store.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/override_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:hablotengo/dev/test_runner_screen.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:oneofus_common/trust_statement.dart';

import 'firebase_options.dart';

late final FirebaseFirestore habloFirestore;
late final FirebaseFirestore oneofusFirestore;
late final FirebaseFunctions habloFunctions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TrustStatement.init();
  ContactStatement.init();
  PrivacyStatement.init();
  OverrideStatement.init();

  final params = Uri.base.queryParameters;
  final fireParam = params['fire'];
  if (fireParam != null) {
    try { fireChoice = FireChoice.values.byName(fireParam); } catch (_) {}
  }

  if (fireChoice != FireChoice.fake) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }
    await OneofusFire.init();

    habloFirestore = FirebaseFirestore.instance;
    habloFunctions = FirebaseFunctions.instance;
    oneofusFirestore = OneofusFire.firestore;

    if (fireChoice == FireChoice.emulator) {
      habloFirestore.useFirestoreEmulator('localhost', 8082);
      habloFunctions.useFunctionsEmulator('127.0.0.1', 5003);
      oneofusFirestore.useFirestoreEmulator('localhost', 8081);
      OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);
    }
  } else {
    habloFirestore = FakeFirebaseFirestore();
    oneofusFirestore = FakeFirebaseFirestore();
    habloFunctions = FirebaseFunctions.instance;
  }

  KeyStorageCoordinator.instance.start();

  // ?demo=simpsons: populate emulators with Simpsons data and sign in as Lisa
  if (params['demo'] == 'simpsons') {
    if (fireChoice == FireChoice.prod) {
      throw Exception('demo= not allowed on production');
    }
    await simpsonsDemo(oneofusDb: oneofusFirestore, habloDb: habloFirestore);
  } else if (fireChoice != FireChoice.fake) {
    // Auto sign-in from stored keys
    try {
      final (idKey, habloKeyPair, endpoint, method) =
          await KeyStore.readKeys().timeout(const Duration(seconds: 5));
      if (idKey != null) {
        final fedKey = FedKey(await idKey.json, endpoint);
        await signInState.signInWithFedKey(fedKey, habloKeyPair, method: method);
      }
    } catch (_) {}
  }

  if (params['tests'] == 'true') {
    runApp(const _TestApp());
  } else {
    runApp(const HablotengoApp());
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabloTengo Tests',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const TestRunnerScreen(),
    );
  }
}
