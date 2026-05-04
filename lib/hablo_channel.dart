import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/jsonish.dart';

import 'sign_in_state.dart';

/// Manages signed writes to the hablotengo statement stream.
///
/// Lazily fetches the current stream head (once per session) so that `previous`
/// is always set correctly without a per-save roundtrip. Serializes writes
/// per delegate key to prevent chain races.
class HabloChannel {
  final String _baseUrl;
  final SignInState _state;

  String? _head;
  bool _headLoaded = false;
  Future<void>? _headFuture;
  Future<void> _writeQueue = Future.value();

  HabloChannel(this._baseUrl, this._state);

  void reset() {
    _head = null;
    _headLoaded = false;
    _headFuture = null;
    _writeQueue = Future.value();
  }

  /// Signs [json] with [signer] and appends it to the stream.
  /// Returns the token of the new statement.
  Future<String> push(Json json, StatementSigner signer) {
    final completer = Completer<String>();
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      try {
        await _ensureHead();
        final Json j = Map.from(json);
        if (_head != null) j['previous'] = _head!;
        final Jsonish jsonish = await Jsonish.makeSign(j, signer);
        await _callWrite(jsonish);
        _head = jsonish.token;
        completer.complete(jsonish.token);
      } catch (e, st) {
        debugPrint('HabloChannel.push error: $e\n$st');
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _ensureHead() async {
    if (_headLoaded) return;
    _headFuture ??= _fetchHead();
    await _headFuture;
  }

  Future<void> _fetchHead() async {
    try {
      final delegateToken = getToken(_state.delegatePublicKeyJson!);
      final response = await http.post(
        Uri.parse('$_baseUrl/getStreamHead'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({..._authPayload(), 'delegateToken': delegateToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _head = data['token'] as String?;
        debugPrint('HabloChannel: head=$_head');
      } else {
        debugPrint('HabloChannel: getStreamHead ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('HabloChannel: getStreamHead error: $e');
    } finally {
      _headLoaded = true;
    }
  }

  Future<void> _callWrite(Jsonish jsonish) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/write'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'statement': jsonish.json,
        ..._authPayload(),
      }),
    );
    if (response.statusCode != 200) {
      debugPrint('HabloChannel._callWrite: ${response.statusCode} ${response.body}');
      throw Exception('write failed: ${response.statusCode} ${response.body}');
    }
  }

  Map<String, dynamic> _authPayload() {
    if (_state.isDemo) {
      return {'identity': _state.identityJson!, 'demo': true};
    }
    return {
      'identity': _state.identityJson!,
      'sessionTime': _state.sessionTime!,
      'sessionSignature': _state.sessionSignature!,
    };
  }
}
