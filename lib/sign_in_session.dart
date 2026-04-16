import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hablotengo/fire_choice.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/main.dart' show habloFirestore;
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey;

class SignInSession {
  final PkeKeyPair pkeKeyPair;
  final String session;
  final Json forPhone;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  SignInSession({required this.forPhone, required this.session, required this.pkeKeyPair});

  static Future<SignInSession> create() async {
    final Json forPhone = {};
    forPhone['domain'] = kHablotengo;
    forPhone['url'] = fireChoice == FireChoice.emulator
        ? 'http://10.0.2.2:5003/demo-hablotengo/us-central1/signin'
        : 'https://signin.$kHablotengo/signin';

    final PkeKeyPair pkeKeyPair = await crypto.createPke();
    final PkePublicKey pkePK = await pkeKeyPair.publicKey;
    final pkePKJson = await pkePK.json;
    final String session = getToken(pkePKJson);
    forPhone['encryptionPk'] = pkePKJson;

    return SignInSession(forPhone: forPhone, session: session, pkeKeyPair: pkeKeyPair);
  }

  Future<void> listen({
    required Function() onDone,
    Duration? timeout,
    SignInMethod method = SignInMethod.qrScan,
  }) async {
    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        cancel();
        onDone();
      });
    }

    // Use hablotengo's own Firestore for session handshake
    _subscription = habloFirestore
        .collection('sessions')
        .doc('doc')
        .collection(session)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      _timeoutTimer?.cancel();
      await cancel();
      onDone();
      await Future.delayed(const Duration(milliseconds: 300));

      final data = snapshot.docs.first.data();
      final String identityKey = data.containsKey('identity') ? 'identity' : kOneofusDomain;
      final Json identityPayload = data[identityKey]!;
      final FedKey fedKey = FedKey.fromPayload(identityPayload) ?? FedKey(identityPayload);
      final OouPublicKey identityPublicKey = await crypto.parsePublicKey(fedKey.pubKeyJson);

      OouKeyPair? habloKeyPair;
      if (data['delegateCiphertext'] != null || data['delegateCleartext'] != null) {
        final String ephemeralKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
        final PkePublicKey phonePkePK = await crypto.parsePkePublicKey(data[ephemeralKey]);
        String? cleartext = data['delegateCleartext'];
        if (cleartext == null) {
          cleartext = await pkeKeyPair.decrypt(data['delegateCiphertext']!, phonePkePK);
        }
        habloKeyPair = await crypto.parseKeyPair(jsonDecode(cleartext!));
      }

      await signInUiHelper(identityPublicKey, habloKeyPair,
          endpoint: fedKey.endpoint, method: method);
    });
  }

  Future<void> cancel() async {
    _timeoutTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
