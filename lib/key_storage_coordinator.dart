import 'package:flutter/foundation.dart';
import 'package:hablotengo/key_store.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

final ValueNotifier<bool> storeKeys = ValueNotifier(true);

class KeyStorageCoordinator {
  KeyStorageCoordinator._();
  static final KeyStorageCoordinator instance = KeyStorageCoordinator._();

  void start() {
    signInState.addListener(_enforce);
    storeKeys.addListener(_enforce);
  }

  void _enforce() { _enforceAsync(); }

  Future<void> _enforceAsync() async {
    if (storeKeys.value && signInState.hasIdentity) {
      final idKey = await crypto.parsePublicKey(Jsonish.find(signInState.identity.value)!.json);
      await KeyStore.storeKeys(idKey, signInState.delegateKeyPair,
          endpoint: signInState.endpoint, method: signInState.signInMethod);
    } else {
      await KeyStore.wipeKeys();
    }
  }
}
