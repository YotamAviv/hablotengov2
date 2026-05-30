import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hablotengo/constants.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';

class SignInState with ChangeNotifier {
  Json? _identityJson;
  String? _sessionTime;
  String? _sessionSignature;
  String? _sessionExpiration;
  String? _sessionSignature2;
  OouKeyPair? _serviceKeyPair;
  bool _isDemo = false;
  OouKeyPair? _delegateKeyPair;
  Json? _delegatePublicKeyJson;
  StatementSigner? _signer;

  bool get hasIdentity => _identityJson != null;
  bool get hasDelegate => _delegateKeyPair != null;
  bool get isDemo => _isDemo;
  bool get hasSession => _sessionTime != null && _sessionSignature != null;
  bool get hasAuth2 => _sessionSignature2 != null && _sessionExpiration != null && _serviceKeyPair != null;

  Json? get identityJson => _identityJson;
  String? get identityToken => _identityJson != null ? getToken(_identityJson!) : null;
  String? get sessionTime => _sessionTime;
  String? get sessionSignature => _sessionSignature;
  String? get sessionExpiration => _sessionExpiration;
  String? get sessionSignature2 => _sessionSignature2;
  OouKeyPair? get serviceKeyPair => _serviceKeyPair;
  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  OouKeyPair? get delegateKeyPair => _delegateKeyPair;
  StatementSigner? get signer => _signer;

  Future<void> onData(Json data, PkeKeyPair pke, OouKeyPair serviceKeyPair) async {
    try {
      _identityJson = data['identity'] as Json?;
      _sessionTime = data['sessionTime'] as String?;
      _sessionSignature = data['sessionSignature'] as String?;
      _sessionExpiration = data['sessionExpiration'] as String?;
      _sessionSignature2 = data['sessionSignature2'] as String?;
      _serviceKeyPair = serviceKeyPair;
      _isDemo = false;
      _delegateKeyPair = null;
      _delegatePublicKeyJson = null;
      _signer = null;
      await _parseDelegate(data, pke);
      debugPrint('SignInState.onData: identityToken=$identityToken hasSession=$hasSession hasDelegate=$hasDelegate auth2=${_sessionSignature2 != null}');
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

  Future<void> restoreKeys(Json identityJson,
      {String? sessionTime, String? sessionSignature,
       String? sessionExpiration, String? sessionSignature2, OouKeyPair? serviceKeyPair,
       OouKeyPair? delegateKeyPair}) async {
    _identityJson = identityJson;
    _sessionTime = sessionTime;
    _sessionSignature = sessionSignature;
    _sessionExpiration = sessionExpiration;
    _sessionSignature2 = sessionSignature2;
    _serviceKeyPair = serviceKeyPair;
    _isDemo = false;
    _delegateKeyPair = null;
    _delegatePublicKeyJson = null;
    _signer = null;
    debugPrint('SignInState.restoreKeys: identityToken=${getToken(identityJson)} hasSession=${sessionTime != null} auth2=${sessionSignature2 != null}');
    if (delegateKeyPair != null) {
      await _setDelegate(delegateKeyPair);
    }
    notifyListeners();
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

  Future<void> signInDemoWithDelegate(Json identityJson, OouKeyPair delegateKeyPair) async {
    _identityJson = identityJson;
    _sessionTime = null;
    _sessionSignature = null;
    _isDemo = true;
    await _setDelegate(delegateKeyPair);
    debugPrint('SignInState.signInDemoWithDelegate: identityToken=${getToken(identityJson)} delegate=${_delegatePublicKeyJson?.toString().substring(0, 20)}...');
    notifyListeners();
  }

  /// Returns the auth payload for CF requests. Returns null if not signed in.
  /// Auth2 (requestCredential) is used when available; falls back to auth1.
  Map<String, dynamic>? authPayload() {
    if (_identityJson == null) return null;
    if (_isDemo) return {'identity': _identityJson!, 'demo': true};
    return {
      'identity': _identityJson!,
      'sessionTime': _sessionTime!,
      'sessionSignature': _sessionSignature!,
    };
  }

  /// Auth2 requestCredential: identity + service key + session credential + signed request time.
  /// Returns null if auth2 is not available.
  Future<Map<String, dynamic>?> requestCredential() async {
    if (_identityJson == null || !hasAuth2) return null;
    if (_isDemo) return {'identity': _identityJson!, 'demo': true};
    final iToken = identityToken!;
    final requestTime = DateTime.now().toUtc().toIso8601String();
    final signedString = '$kHabloDomain-$iToken-$_sessionExpiration-$_sessionSignature2-$requestTime';
    final requestSignature = await _serviceKeyPair!.sign(signedString);
    final servicePkJson = await (await _serviceKeyPair!.publicKey).json;
    return {
      'identity': _identityJson!,
      'servicePk': servicePkJson,
      'sessionExpiration': _sessionExpiration!,
      'sessionSignature2': _sessionSignature2!,
      'requestTime': requestTime,
      'requestSignature': requestSignature,
    };
  }

  void signOut() {
    debugPrint('SignInState.signOut: was identityToken=$identityToken');
    _identityJson = null;
    _sessionTime = null;
    _sessionSignature = null;
    _sessionExpiration = null;
    _sessionSignature2 = null;
    _serviceKeyPair = null;
    _isDemo = false;
    _delegateKeyPair = null;
    _delegatePublicKeyJson = null;
    _signer = null;
    notifyListeners();
  }
}

final SignInState signInState = SignInState();
