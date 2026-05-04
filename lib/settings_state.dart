import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'contact_service.dart' show setSettingsField;
import 'sign_in_state.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();
const String _kShowEmptyCards  = 'hablo_pref_show_empty_cards';
const String _kShowHiddenCards = 'hablo_pref_show_hidden_cards';
const String _kShowCrypto      = 'hablo_pref_show_crypto';

final SettingsState settingsState = SettingsState();

class SettingsState extends ChangeNotifier {
  bool showEmptyCards = false;
  bool showHiddenCards = false;
  bool showCrypto = false;
  String defaultStrictness = 'standard'; // 'permissive', 'standard', 'strict'

  Future<void> load(bool emulator) async {
    // Preferences are local — read from secure storage.
    showEmptyCards  = (await _storage.read(key: _kShowEmptyCards))  == '1';
    showHiddenCards = (await _storage.read(key: _kShowHiddenCards)) == '1';
    showCrypto      = (await _storage.read(key: _kShowCrypto))      == '1';

    // defaultStrictness is a signed setting — fetch from server.
    try {
      final response = await http.post(
        Uri.parse(habloGetSettingsUrl(emulator)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_authPayload()),
      );
      if (response.statusCode != 200) {
        debugPrint('SettingsState.load error: ${response.statusCode} ${response.body}');
        notifyListeners();
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      defaultStrictness = data['defaultStrictness'] as String? ?? 'standard';
    } catch (e) {
      debugPrint('SettingsState.load error: $e');
    }
    notifyListeners();
  }

  void reset() {
    showEmptyCards = false;
    showHiddenCards = false;
    showCrypto = false;
    defaultStrictness = 'standard';
    notifyListeners();
  }

  Future<void> setShowEmptyCards(bool value) async {
    showEmptyCards = value;
    notifyListeners();
    try {
      await _storage.write(key: _kShowEmptyCards, value: value ? '1' : '0');
    } catch (e) {
      debugPrint('SettingsState.setShowEmptyCards error: $e');
    }
  }

  Future<void> setShowHiddenCards(bool value) async {
    showHiddenCards = value;
    notifyListeners();
    try {
      await _storage.write(key: _kShowHiddenCards, value: value ? '1' : '0');
    } catch (e) {
      debugPrint('SettingsState.setShowHiddenCards error: $e');
    }
  }

  Future<void> setShowCrypto(bool value) async {
    showCrypto = value;
    notifyListeners();
    try {
      await _storage.write(key: _kShowCrypto, value: value ? '1' : '0');
    } catch (e) {
      debugPrint('SettingsState.setShowCrypto error: $e');
    }
  }

  Future<void> setDefaultStrictness(String value, bool emulator) async {
    defaultStrictness = value;
    notifyListeners();
    try {
      await setSettingsField('defaultStrictness', value, emulator);
    } catch (e) {
      debugPrint('SettingsState.setDefaultStrictness error: $e');
    }
  }

  Map<String, dynamic> _authPayload() {
    if (signInState.isDemo) {
      return {'identity': signInState.identityJson!, 'demo': true};
    }
    return {
      'identity': signInState.identityJson!,
      'sessionTime': signInState.sessionTime!,
      'sessionSignature': signInState.sessionSignature!,
    };
  }
}
