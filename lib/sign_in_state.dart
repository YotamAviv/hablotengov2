import 'package:flutter/foundation.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/jsonish.dart';

class SignInState with ChangeNotifier {
  Json? _identityJson;
  String? _sessionTime;
  String? _sessionSignature;
  bool _isDemo = false;

  bool get hasIdentity => _identityJson != null;
  bool get hasDelegate => false; // Hablo does not use delegate keys
  bool get isDemo => _isDemo;
  bool get hasSession => _sessionTime != null && _sessionSignature != null;

  Json? get identityJson => _identityJson;
  String? get identityToken => _identityJson != null ? getToken(_identityJson!) : null;
  String? get sessionTime => _sessionTime;
  String? get sessionSignature => _sessionSignature;

  // Called by SignInDialog.onData when the phone responds.
  Future<void> onData(Json data, PkeKeyPair pke) async {
    try {
      _identityJson = data['identity'] as Json?;
      _sessionTime = data['sessionTime'] as String?;
      _sessionSignature = data['sessionSignature'] as String?;
      _isDemo = false;
      debugPrint('SignInState.onData: identityToken=$identityToken hasSession=$hasSession');
      notifyListeners();
    } catch (e, st) {
      debugPrint('SignInState.onData error: $e\n$st');
    }
  }

  // Called by tryRestoreKeys on app startup (real auth restore).
  void restoreKeys(Json identityJson, {String? sessionTime, String? sessionSignature}) {
    _identityJson = identityJson;
    _sessionTime = sessionTime;
    _sessionSignature = sessionSignature;
    _isDemo = false;
    debugPrint('SignInState.restoreKeys: identityToken=$identityToken hasSession=$hasSession');
    notifyListeners();
  }

  // Called by demo sign-in.
  void restoreDemoKeys(Json identityJson) {
    _identityJson = identityJson;
    _sessionTime = null;
    _sessionSignature = null;
    _isDemo = true;
    debugPrint('SignInState.restoreDemoKeys: identityToken=$identityToken');
    notifyListeners();
  }

  void signOut() {
    debugPrint('SignInState.signOut: was identityToken=$identityToken');
    _identityJson = null;
    _sessionTime = null;
    _sessionSignature = null;
    _isDemo = false;
    notifyListeners();
  }
}

final SignInState signInState = SignInState();
