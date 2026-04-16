import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/logic/hablo_statement_writer.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';

/// Demo identity key — creates a real key pair in memory.
class DemoIdentityKey {
  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;

  DemoIdentityKey._(this.name, this.keyPair, this.publicKey, this.token);

  static Future<DemoIdentityKey> create(String name) async {
    final kp = await crypto.createKeyPair();
    final pk = await kp.publicKey;
    final json = await pk.json;
    Jsonish(json); // register in Jsonish cache
    return DemoIdentityKey._(name, kp, pk, Jsonish(json).token);
  }

  Future<TrustStatement> trust(
    DemoIdentityKey other,
    FirebaseFirestore oneofusDb, {
    String? moniker,
  }) async {
    moniker ??= other.name;
    final iJson = await publicKey.json;
    final subjectJson = await other.publicKey.json;
    final json = await TrustStatement.make(iJson, subjectJson, TrustVerb.trust, moniker: moniker);
    final writer = DirectFirestoreWriter<TrustStatement>(oneofusDb);
    final signer = await OouSigner.make(keyPair);
    return await writer.push(json, signer) as TrustStatement;
  }

  Future<TrustStatement> delegateTo(
    DemoDelegateKey dk,
    FirebaseFirestore oneofusDb,
  ) async {
    final iJson = await publicKey.json;
    final dkJson = await dk.publicKey.json;
    final json = await TrustStatement.make(iJson, dkJson, TrustVerb.delegate, domain: kHablotengo);
    final writer = DirectFirestoreWriter<TrustStatement>(oneofusDb);
    final signer = await OouSigner.make(keyPair);
    return await writer.push(json, signer) as TrustStatement;
  }
}

/// Demo hablotengo delegate key.
class DemoDelegateKey {
  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  final String token;

  DemoDelegateKey._(this.name, this.keyPair, this.publicKey, this.token);

  static Future<DemoDelegateKey> create(String name) async {
    final kp = await crypto.createKeyPair();
    final pk = await kp.publicKey;
    final json = await pk.json;
    Jsonish(json); // register in Jsonish cache
    return DemoDelegateKey._(name, kp, pk, Jsonish(json).token);
  }

  Future<void> submitCard(
    FirebaseFirestore habloDb,
    FirebaseFirestore oneofusDb, {
    String? name,
    String? email,
    String? phone,
    Map<String, List<Map<String, dynamic>>> contactPrefs = const {},
    VisibilityLevel visibility = VisibilityLevel.standard,
  }) async {
    final iJson = await publicKey.json;
    final signer = await OouSigner.make(keyPair);

    final contactJson = ContactStatement.buildJson(
      iJson: iJson,
      name: name,
      emails: email != null ? [{'address': email, 'preferred': true}] : [],
      phones: phone != null ? [{'number': phone, 'preferred': false}] : [],
      contactPrefs: contactPrefs,
    );
    final contactWriter = HabloStatementWriter<ContactStatement>(habloDb, kHabloContactCollection);
    await contactWriter.push(contactJson, signer);

    final privacyJson = PrivacyStatement.buildJson(iJson: iJson, level: visibility);
    final privacyWriter = HabloStatementWriter<PrivacyStatement>(habloDb, kHabloPrivacyCollection);
    await privacyWriter.push(privacyJson, signer);
  }
}
