import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/dev/simpsons_demo.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/hablotengo_fire.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/logic/hablo_cloud_functions.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/override_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TrustStatement.init();
  ContactStatement.init();
  PrivacyStatement.init();
  OverrideStatement.init();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }
  await OneofusFire.init();

  final habloFirestore = FirebaseFirestore.instance;
  final habloFunctions = FirebaseFunctions.instance;
  final oneofusFirestore = OneofusFire.firestore;

  habloFirestore.useFirestoreEmulator('127.0.0.1', 8082);
  habloFunctions.useFunctionsEmulator('127.0.0.1', 5003);
  oneofusFirestore.useFirestoreEmulator('127.0.0.1', 8083);
  OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5004);

  const oneofusTrustUrl = 'http://127.0.0.1:5004/one-of-us-net/us-central1/export';

  runApp(WidgetRunner(scenario: () async {
    debugPrint('--- seeding simpsons demo ---');
    await simpsonsDemo(oneofusDb: oneofusFirestore, habloFunctions: habloFunctions);
    debugPrint('--- simpsons demo seeded ---');

    final trustSource = CloudFunctionsSource<TrustStatement>(
      baseUrl: oneofusTrustUrl,
      verifier: OouVerifier(),
    );
    final repo = ContactRepo(
      trustSource: trustSource,
      habloFirestore: habloFirestore,
      cloudFunctions: HabloCloudFunctions(habloFunctions),
    );

    final result = await repo.loadContacts(IdentityKey(signInState.pov));
    debugPrint('loadContacts returned ${result.contacts.length} entries');
    assert(result.contacts.length >= 4, 'Expected at least 4 contacts, got ${result.contacts.length}');

    debugPrint('PASS');
  }));
}
