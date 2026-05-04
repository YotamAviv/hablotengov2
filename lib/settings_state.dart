import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'contact_service.dart' show setSettingsField;
import 'sign_in_state.dart';

final SettingsState settingsState = SettingsState();

class SettingsState extends ChangeNotifier {
  bool showEmptyCards = false;
  bool showHiddenCards = false;
  String defaultStrictness = 'standard'; // 'permissive', 'standard', 'strict'

  Future<void> load(bool emulator) async {
    try {
      final response = await http.post(
        Uri.parse(habloGetSettingsUrl(emulator)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_authPayload()),
      );
      if (response.statusCode != 200) {
        debugPrint('SettingsState.load error: ${response.statusCode} ${response.body}');
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      showEmptyCards = data['showEmptyCards'] as bool? ?? false;
      showHiddenCards = data['showHiddenCards'] as bool? ?? false;
      defaultStrictness = data['defaultStrictness'] as String? ?? 'standard';
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsState.load error: $e');
    }
  }

  void reset() {
    showEmptyCards = false;
    showHiddenCards = false;
    defaultStrictness = 'standard';
    notifyListeners();
  }

  Future<void> setShowEmptyCards(bool value, bool emulator) async {
    showEmptyCards = value;
    notifyListeners();
    await _saveField('showEmptyCards', value, emulator);
  }

  Future<void> setShowHiddenCards(bool value, bool emulator) async {
    showHiddenCards = value;
    notifyListeners();
    await _saveField('showHiddenCards', value, emulator);
  }

  Future<void> setDefaultStrictness(String value, bool emulator) async {
    defaultStrictness = value;
    notifyListeners();
    await _saveField('defaultStrictness', value, emulator);
  }

  Future<void> _saveField(String field, dynamic value, bool emulator) async {
    try {
      await setSettingsField(field, value, emulator);
    } catch (e) {
      debugPrint('SettingsState.save error: $e');
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
