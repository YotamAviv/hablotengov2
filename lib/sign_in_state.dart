import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey, IdentityKey, kNativeEndpoint;
import 'package:oneofus_common/oou_signer.dart';

enum SignInMethod { qrScan, paste, url }

final SignInState signInState = SignInState();

Future<void> signInUiHelper(
    OouPublicKey oneofusPublicKey, OouKeyPair? habloKeyPair,
    {Map<String, dynamic> endpoint = kNativeEndpoint, SignInMethod? method}) async {
  final fedKey = FedKey(await oneofusPublicKey.json, endpoint);
  await signInState.signInWithFedKey(fedKey, habloKeyPair, method: method);
}

class SignInState with ChangeNotifier {
  final ValueNotifier<String?> povNotifier = ValueNotifier<String?>(null);
  IdentityKey? _identity;
  Json? _delegatePublicKeyJson;
  String? _delegate;
  StatementSigner? _signer;
  OouKeyPair? _delegateKeyPair;
  Map<String, dynamic> _endpoint = kNativeEndpoint;
  SignInMethod? _signInMethod;

  static final SignInState _singleton = SignInState._internal();
  SignInState._internal();
  factory SignInState() => _singleton;

  set pov(String oneofusToken) {
    assert(Jsonish.find(oneofusToken) != null);
    povNotifier.value = oneofusToken;
    notifyListeners();
  }

  Future<void> signInWithFedKey(FedKey fedKey, OouKeyPair? delegateKeyPair,
      {SignInMethod? method}) async {
    _identity = fedKey.identityKey;
    _endpoint = fedKey.endpoint;
    _signInMethod = method;
    povNotifier.value = fedKey.identityKey.value;
    _delegateKeyPair = delegateKeyPair;
    if (delegateKeyPair != null) {
      OouPublicKey pk = await delegateKeyPair.publicKey;
      _delegatePublicKeyJson = await pk.json;
      _delegate = getToken(_delegatePublicKeyJson);
      _signer = await OouSigner.make(delegateKeyPair);
    } else {
      _delegatePublicKeyJson = null;
      _delegate = null;
      _signer = null;
    }
    notifyListeners();
  }

  void signOut() {
    if (povNotifier.value == _identity?.value) povNotifier.value = null;
    _identity = null;
    _delegatePublicKeyJson = null;
    _delegate = null;
    _signer = null;
    _delegateKeyPair = null;
    _signInMethod = null;
    notifyListeners();
  }

  bool get hasPov => povNotifier.value != null;
  bool get hasIdentity => _identity != null;
  bool get canWrite => _delegate != null && _signer != null;

  String get pov {
    if (povNotifier.value != null) return povNotifier.value!;
    if (_identity == null) throw StateError('Accessed pov before sign in');
    return _identity!.value;
  }

  IdentityKey get identity {
    if (_identity == null) throw StateError('Accessed identity before sign in');
    return _identity!;
  }

  Json get identityJson => Jsonish.find(identity.value)!.json;

  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  String? get delegate => _delegate;
  StatementSigner? get signer => _signer;
  OouKeyPair? get delegateKeyPair => _delegateKeyPair;
  Map<String, dynamic> get endpoint => _endpoint;
  SignInMethod? get signInMethod => _signInMethod;

  /// Builds the delegate auth proof bundle for the getContactInfo Cloud Function.
  /// [delegateStatement] is the signed trust statement proving identity→delegate.
  Future<Json?> buildDelegateAuth(Json delegateStatement) async {
    if (_delegateKeyPair == null || _delegatePublicKeyJson == null) return null;
    final nonce = List<int>.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final challenge = '${DateTime.now().toUtc().toIso8601String()} $nonce';
    final sig = await _delegateKeyPair!.sign(challenge);
    return {
      'challenge': challenge,
      'challengeSignature': sig,
      'delegatePublicKey': _delegatePublicKeyJson,
      'delegateStatement': delegateStatement,
    };
  }
}
