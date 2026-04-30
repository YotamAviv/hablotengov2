import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'sign_in_state.dart';

final SettingsState settingsState = SettingsState();

class SettingsState extends ChangeNotifier {
  bool showEmptyCards = false;
  bool showHiddenCards = false;

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
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsState.load error: $e');
    }
  }

  void reset() {
    showEmptyCards = false;
    showHiddenCards = false;
    notifyListeners();
  }

  Future<void> setShowEmptyCards(bool value, bool emulator) async {
    showEmptyCards = value;
    notifyListeners();
    await _save(emulator);
  }

  Future<void> setShowHiddenCards(bool value, bool emulator) async {
    showHiddenCards = value;
    notifyListeners();
    await _save(emulator);
  }

  Future<void> _save(bool emulator) async {
    try {
      final response = await http.post(
        Uri.parse(habloSetSettingsUrl(emulator)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          ..._authPayload(),
          'showEmptyCards': showEmptyCards,
          'showHiddenCards': showHiddenCards,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('SettingsState.save error: ${response.statusCode} ${response.body}');
      }
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
