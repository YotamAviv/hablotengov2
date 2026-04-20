import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/dev/demo_key.dart';
import 'package:hablotengo/dev/widget_runner.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/override_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TrustStatement.init();
  ContactStatement.init();
  PrivacyStatement.init();
  OverrideStatement.init();

  runApp(WidgetRunner(scenario: () async {
    final oneofusDb = FakeFirebaseFirestore();
    final habloDb = FakeFirebaseFirestore();

    final lisa = await DemoIdentityKey.create('lisa');
    final homer = await DemoIdentityKey.create('homer');
    final lisaD = await DemoDelegateKey.create('lisa-hablo');
    final homerD = await DemoDelegateKey.create('homer-hablo');

    await homer.trust(lisa, oneofusDb);
    await lisa.trust(homer, oneofusDb);
    await lisa.delegateTo(lisaD, oneofusDb);
    await homer.delegateTo(homerD, oneofusDb);

    final contactWriter = DirectFirestoreWriter<Statement>(habloDb, streamId: kHabloContactCollection);
    final privacyWriter = DirectFirestoreWriter<Statement>(habloDb, streamId: kHabloPrivacyCollection);
    await lisaD.submitCard(contactWriter: contactWriter, privacyWriter: privacyWriter, name: 'Lisa', email: 'lisa@test.com');
    await homerD.submitCard(contactWriter: contactWriter, privacyWriter: privacyWriter, name: 'Homer', email: 'homer@test.com');

    final repo = ContactRepo(
      trustSource: DirectFirestoreSource<TrustStatement>(oneofusDb),
      habloFirestore: habloDb,
    );
    final result = await repo.loadContacts(IdentityKey(lisa.token));
    assert(result.contacts.length >= 2, 'Expected at least 2 contacts, got ${result.contacts.length}');

    debugPrint('PASS');
  }));
}
