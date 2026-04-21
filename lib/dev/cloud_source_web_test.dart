import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/dev/simpsons_demo.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/firebase_options.dart';
import 'package:hablotengo/hablotengo_fire.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/logic/delegates.dart';
import 'package:hablotengo/logic/hablo_cloud_functions.dart';
import 'package:hablotengo/logic/proof_builder.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/cloud_functions_writer.dart';
import 'package:oneofus_common/statement_writer.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TrustStatement.init();
  ContactStatement.init();
  PrivacyStatement.init();

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
    final contactWriter = CloudFunctionsWriter<Statement>(habloFunctions, kHabloContactCollection);
    final privacyWriter = CloudFunctionsWriter<Statement>(habloFunctions, kHabloPrivacyCollection);
    await simpsonsDemo(oneofusDb: oneofusFirestore, habloContactWriter: contactWriter, habloPrivacyWriter: privacyWriter);
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

    final pov = IdentityKey(signInState.pov);

    final result = await repo.loadContacts(pov);
    debugPrint('loadContacts returned ${result.contacts.length} entries');
    assert(result.contacts.length >= 4, 'Expected at least 4 contacts, got ${result.contacts.length}');

    // Test loadMyCard
    final delegates = DelegateResolver(result.graph);
    delegates.resolveForIdentity(pov);
    final myDelegateKeys = delegates
        .getDelegatesForIdentity(pov)
        .where((dk) => delegates.getDomainForDelegate(dk) == kHablotengo)
        .toList();
    debugPrint('myDelegateKeys: ${myDelegateKeys.length}');
    assert(myDelegateKeys.isNotEmpty, 'Expected at least one hablotengo delegate key for pov');

    final delegateStatement = findDelegateStatement(result.graph, pov, myDelegateKeys.first.value);
    debugPrint('delegateStatement: ${delegateStatement != null ? "found" : "null"}');
    assert(delegateStatement != null, 'Expected delegate statement in graph');

    final card = await repo.loadMyCard(myDelegateKeys, delegateStatement: delegateStatement);
    debugPrint('loadMyCard contact: ${card.contact?.name}');
    assert(card.contact != null, 'Expected contact to be non-null');
    assert(card.contact!.name == 'Lisa Simpson', 'Expected name "Lisa Simpson", got "${card.contact!.name}"');

    // Test save round-trip: write an updated card via CF, then load it back
    final signer = signInState.signer!;
    final delegateJson = signInState.delegatePublicKeyJson!;
    final updatedContactJson = ContactStatement.buildJson(
      iJson: delegateJson,
      name: 'Lisa Simpson Updated',
      emails: [{'address': 'lisa2@springfield.edu', 'preferred': true}],
    );
    await contactWriter.push(updatedContactJson, signer,
        previous: ExpectedPrevious(card.contact!.token));
    debugPrint('writeStatement done');

    final card2 = await repo.loadMyCard(myDelegateKeys, delegateStatement: delegateStatement);
    debugPrint('loadMyCard after save: ${card2.contact?.name}');
    assert(card2.contact?.name == 'Lisa Simpson Updated',
        'Expected "Lisa Simpson Updated", got "${card2.contact?.name}"');

    debugPrint('PASS');
  }));
}
