import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

import 'sign_in_state.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();
const String _kIdentityKey = 'hablo_identity';
const String _kSessionTimeKey = 'hablo_session_time';
const String _kSessionSigKey = 'hablo_session_sig';
const String _kIsDemoKey = 'hablo_is_demo';
const String _kDelegateKey = 'hablo_delegate';

final ValueNotifier<bool> storeKeys = ValueNotifier(true);

void startKeyStorageCoordinator() {
  signInState.addListener(_enforce);
  storeKeys.addListener(_enforce);
}

void _enforce() => _enforceAsync();

Future<void> _enforceAsync() async {
  if (storeKeys.value && signInState.hasIdentity) {
    try {
      await _storage.write(key: _kIdentityKey, value: jsonEncode(signInState.identityJson));
      await _storage.write(key: _kSessionTimeKey, value: signInState.sessionTime ?? '');
      await _storage.write(key: _kSessionSigKey, value: signInState.sessionSignature ?? '');
      await _storage.write(key: _kIsDemoKey, value: signInState.isDemo ? '1' : '0');
      final delegateKeyPair = signInState.delegateKeyPair;
      if (delegateKeyPair != null) {
        final delegateJson = await delegateKeyPair.json;
        await _storage.write(key: _kDelegateKey, value: jsonEncode(delegateJson));
      } else {
        await _storage.delete(key: _kDelegateKey);
      }
    } catch (e) {
      debugPrint('HabloKeyStore write error: $e');
    }
  } else {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('HabloKeyStore wipe error: $e');
    }
  }
}

Future<void> tryRestoreKeys() async {
  try {
    final String? identityStr = await _storage.read(key: _kIdentityKey);
    if (identityStr == null) return;
    final Json identityJson = jsonDecode(identityStr) as Json;
    final String? sessionTime = await _storage.read(key: _kSessionTimeKey);
    final String? sessionSig = await _storage.read(key: _kSessionSigKey);
    final bool isDemo = (await _storage.read(key: _kIsDemoKey)) == '1';

    OouKeyPair? delegateKeyPair;
    final String? delegateStr = await _storage.read(key: _kDelegateKey);
    if (delegateStr != null) {
      try {
        final Json delegateJson = jsonDecode(delegateStr) as Json;
        delegateKeyPair = await crypto.parseKeyPair(delegateJson);
      } catch (e) {
        debugPrint('HabloKeyStore: failed to parse delegate key pair: $e');
      }
    }

    if (isDemo) {
      signInState.restoreDemoKeys(identityJson);
    } else {
      signInState.restoreKeys(
        identityJson,
        sessionTime: sessionTime?.isEmpty == true ? null : sessionTime,
        sessionSignature: sessionSig?.isEmpty == true ? null : sessionSig,
        delegateKeyPair: delegateKeyPair,
      );
    }
  } catch (e) {
    debugPrint('HabloKeyStore restore error: $e');
  }
}
