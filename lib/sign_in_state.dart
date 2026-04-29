import 'package:flutter/foundation.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/jsonish.dart';

class SignInState with ChangeNotifier {
  Json? _identityJson;

  bool get hasIdentity => _identityJson != null;
  bool get hasDelegate => false; // Hablo does not use delegate keys
  Json? get identityJson => _identityJson;
  String? get identityToken => _identityJson != null ? getToken(_identityJson!) : null;

  // Called by SignInDialog.onData when the phone responds.
  // pke is provided by SignInSession but unused — Hablo does not use delegate keys.
  Future<void> onData(Json data, PkeKeyPair pke) async {
    try {
      _identityJson = data['identity'] as Json?;
      debugPrint('SignInState.onData: identityToken=$identityToken');
      notifyListeners();
    } catch (e, st) {
      debugPrint('SignInState.onData error: $e\n$st');
    }
  }

  // Called by tryRestoreKeys on app startup.
  void restoreKeys(Json identityJson) {
    _identityJson = identityJson;
    debugPrint('SignInState.restoreKeys: identityToken=$identityToken');
    notifyListeners();
  }

  void signOut() {
    debugPrint('SignInState.signOut: was identityToken=$identityToken');
    _identityJson = null;
    notifyListeners();
  }
}

final SignInState signInState = SignInState();
