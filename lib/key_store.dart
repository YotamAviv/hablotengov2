import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/sign_in_state.dart';

class KeyStore {
  static const _storage = FlutterSecureStorage();
  static const _encoder = Jsonish.encoder;
  static const _kFedKeyKey = 'oneofus_home';
  static const _kSignInMethod = 'signInMethod';

  static Future<void> storeKeys(
    OouPublicKey identityPublicKey,
    OouKeyPair? habloKeyPair, {
    Map<String, dynamic> endpoint = kNativeEndpoint,
    SignInMethod? method,
  }) async {
    await _storage.write(key: kOneofusDomain, value: _encoder.convert(await identityPublicKey.json));
    await _storage.write(key: _kFedKeyKey, value: _encoder.convert(endpoint));
    if (method != null) {
      await _storage.write(key: _kSignInMethod, value: method.name);
    } else {
      await _storage.delete(key: _kSignInMethod);
    }
    if (habloKeyPair != null) {
      await _storage.write(key: kHablotengo, value: _encoder.convert(await habloKeyPair.json));
    } else {
      await _storage.delete(key: kHablotengo);
    }
  }

  static Future<void> wipeKeys() async {
    await _storage.delete(key: kOneofusDomain);
    await _storage.delete(key: kHablotengo);
    await _storage.delete(key: _kFedKeyKey);
    await _storage.delete(key: _kSignInMethod);
  }

  static Future<(OouPublicKey?, OouKeyPair?, Map<String, dynamic>, SignInMethod?)> readKeys() async {
    OouPublicKey? identityPublicKey;
    final idStr = await _storage.read(key: kOneofusDomain);
    if (idStr != null) {
      identityPublicKey = await crypto.parsePublicKey(jsonDecode(idStr));
    }

    OouKeyPair? habloKeyPair;
    final habloStr = await _storage.read(key: kHablotengo);
    if (habloStr != null) {
      habloKeyPair = await crypto.parseKeyPair(jsonDecode(habloStr));
    }

    Map<String, dynamic> endpoint = kNativeEndpoint;
    final stored = await _storage.read(key: _kFedKeyKey);
    if (stored != null) {
      final parsed = jsonDecode(stored);
      if (parsed is Map<String, dynamic>) {
        endpoint = parsed;
      } else if (parsed is String) {
        endpoint = {'url': 'https://$parsed'};
      }
    }

    SignInMethod? method;
    final methodStr = await _storage.read(key: _kSignInMethod);
    if (methodStr != null) {
      try {
        method = SignInMethod.values.byName(methodStr);
      } catch (_) {}
    }

    return (identityPublicKey, habloKeyPair, endpoint, method);
  }
}
