import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/jsonish.dart';

import 'sign_in_state.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();
const String _kIdentityKey = 'hablo_identity';

final ValueNotifier<bool> storeKeys = ValueNotifier(true);

void startKeyStorageCoordinator() {
  signInState.addListener(_enforce);
  storeKeys.addListener(_enforce);
}

void _enforce() => _enforceAsync();

Future<void> _enforceAsync() async {
  if (storeKeys.value && signInState.hasIdentity) {
    try {
      await _storage.write(
          key: _kIdentityKey, value: jsonEncode(signInState.identityJson));
    } catch (e) {
      debugPrint('HabloKeyStore write error: $e');
    }
  } else {
    try {
      await _storage.delete(key: _kIdentityKey);
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
    signInState.restoreKeys(identityJson);
  } catch (e) {
    debugPrint('HabloKeyStore restore error: $e');
  }
}
