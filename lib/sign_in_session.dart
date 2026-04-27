// App-specific sign-in wiring for Hablotengo. Parallel to nerdster14/lib/sign_in_session.dart.
// Shared session mechanics live in nerdster_common/lib/sign_in_session.dart.

import 'dart:convert';

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/fire_choice.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey;

export 'package:nerdster_common/sign_in_session.dart';

Future<SignInSession> createHabloSignInSession() {
  final url = fireChoice == FireChoice.emulator
      ? 'http://10.0.2.2:5003/demo-hablotengo/us-central1/signIn'
      : kHabloSigninUrl;
  return SignInSession.create(domain: kHablotengo, signInUrl: url);
}

Future<void> habloOnSessionData(Json data, PkeKeyPair pkeKeyPair) async {
  final String identityKey = data.containsKey('identity') ? 'identity' : kOneofusDomain;
  final Json identityPayload = data[identityKey]!;
  final FedKey fedKey = FedKey.fromPayload(identityPayload) ?? FedKey(identityPayload);
  final OouPublicKey identityPublicKey = await crypto.parsePublicKey(fedKey.pubKeyJson);

  OouKeyPair? habloKeyPair;
  if (data['delegateCiphertext'] != null || data['delegateCleartext'] != null) {
    final String ephemeralKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
    final PkePublicKey phonePkePK = await crypto.parsePkePublicKey(data[ephemeralKey]);
    String? cleartext = data['delegateCleartext'];
    cleartext ??= await pkeKeyPair.decrypt(data['delegateCiphertext'], phonePkePK);
    habloKeyPair = await crypto.parseKeyPair(jsonDecode(cleartext));
  }

  await signInUiHelper(identityPublicKey, habloKeyPair,
      endpoint: fedKey.endpoint, method: SignInMethod.qrScan);
}
