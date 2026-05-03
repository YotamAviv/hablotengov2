import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';

class SignInState with ChangeNotifier {
  Json? _identityJson;
  String? _sessionTime;
  String? _sessionSignature;
  bool _isDemo = false;
  OouKeyPair? _delegateKeyPair;
  Json? _delegatePublicKeyJson;
  StatementSigner? _signer;

  bool get hasIdentity => _identityJson != null;
  bool get hasDelegate => _delegateKeyPair != null;
  bool get isDemo => _isDemo;
  bool get hasSession => _sessionTime != null && _sessionSignature != null;

  Json? get identityJson => _identityJson;
  String? get identityToken => _identityJson != null ? getToken(_identityJson!) : null;
  String? get sessionTime => _sessionTime;
  String? get sessionSignature => _sessionSignature;
  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  OouKeyPair? get delegateKeyPair => _delegateKeyPair;
  StatementSigner? get signer => _signer;

  Future<void> onData(Json data, PkeKeyPair pke) async {
    try {
      _identityJson = data['identity'] as Json?;
      _sessionTime = data['sessionTime'] as String?;
      _sessionSignature = data['sessionSignature'] as String?;
      _isDemo = false;
      _delegateKeyPair = null;
      _delegatePublicKeyJson = null;
      _signer = null;
      await _parseDelegate(data, pke);
      debugPrint('SignInState.onData: identityToken=$identityToken hasSession=$hasSession hasDelegate=$hasDelegate');
      notifyListeners();
    } catch (e, st) {
      debugPrint('SignInState.onData error: $e\n$st');
    }
  }

  Future<void> _parseDelegate(Json data, PkeKeyPair pke) async {
    if (data['delegateCiphertext'] == null && data['delegateCleartext'] == null) return;
    try {
      final String ephemeralPKKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
      final PkePublicKey phonePke = await crypto.parsePkePublicKey(data[ephemeralPKKey]);
      String? cleartext = data['delegateCleartext'] as String?;
      if (data['delegateCiphertext'] != null) {
        cleartext = await pke.decrypt(data['delegateCiphertext'] as String, phonePke);
      }
      final Json delegateJson = jsonDecode(cleartext!) as Json;
      await _setDelegate(await crypto.parseKeyPair(delegateJson));
    } catch (e, st) {
      debugPrint('SignInState._parseDelegate error: $e\n$st');
    }
  }

  Future<void> _setDelegate(OouKeyPair keyPair) async {
    _delegateKeyPair = keyPair;
    final OouPublicKey pk = await keyPair.publicKey;
    _delegatePublicKeyJson = await pk.json;
    _signer = await OouSigner.make(keyPair);
  }

  void restoreKeys(Json identityJson,
      {String? sessionTime, String? sessionSignature, OouKeyPair? delegateKeyPair}) {
    _identityJson = identityJson;
    _sessionTime = sessionTime;
    _sessionSignature = sessionSignature;
    _isDemo = false;
    _delegateKeyPair = null;
    _delegatePublicKeyJson = null;
    _signer = null;
    debugPrint('SignInState.restoreKeys: identityToken=${getToken(identityJson)} hasSession=${sessionTime != null}');
    if (delegateKeyPair != null) {
      _setDelegate(delegateKeyPair).then((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void restoreDemoKeys(Json identityJson) {
    _identityJson = identityJson;
    _sessionTime = null;
    _sessionSignature = null;
    _isDemo = true;
    _delegateKeyPair = null;
    _delegatePublicKeyJson = null;
    _signer = null;
    debugPrint('SignInState.restoreDemoKeys: identityToken=${getToken(identityJson)}');
    notifyListeners();
  }

  void signOut() {
    debugPrint('SignInState.signOut: was identityToken=$identityToken');
    _identityJson = null;
    _sessionTime = null;
    _sessionSignature = null;
    _isDemo = false;
    _delegateKeyPair = null;
    _delegatePublicKeyJson = null;
    _signer = null;
    notifyListeners();
  }
}

final SignInState signInState = SignInState();
