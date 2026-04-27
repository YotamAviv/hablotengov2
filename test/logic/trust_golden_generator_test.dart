import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';

/// Reads functions/test/trust_fixture.json and trust_characters.json,
/// runs the Dart TrustPipeline from each character's PoV, and writes
/// functions/test/trust_golden.json.
///
/// Run after generate_trust_fixtures.js:
///   flutter test test/logic/trust_golden_generator_test.dart
void main() {
  test('Generate trust golden file', () async {
    TrustStatement.init();

    final fixture = jsonDecode(File('functions/test/trust_fixture.json').readAsStringSync()) as Map<String, dynamic>;
    final characters = jsonDecode(File('functions/test/trust_characters.json').readAsStringSync()) as Map<String, dynamic>;

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {};
    for (final entry in fixture.entries) {
      final token = entry.key;
      final stmts = (entry.value as List).map((json) {
        return Statement.make(Jsonish(json as Map<String, dynamic>)) as TrustStatement;
      }).toList();
      byIssuer[IdentityKey(token)] = stmts;
    }

    final source = _FixtureSource(byIssuer);

    final Map<String, dynamic> golden = {};
    for (final entry in characters.entries) {
      final name = entry.key;
      final token = entry.value as String;
      final pipeline = TrustPipeline(source, pathRequirement: TrustPipeline.defaultPathRequirement);
      final graph = await pipeline.build(IdentityKey(token));
      golden[name] = {
        'token': token,
        'orderedKeys': graph.orderedKeys.map((k) => k.value).toList(),
      };
    }

    const encoder = JsonEncoder.withIndent('  ');
    await File('functions/test/trust_golden.json').writeAsString(encoder.convert(golden));

    print('Wrote trust_golden.json (${golden.length} characters).');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _FixtureSource implements StatementSource<TrustStatement> {
  final Map<IdentityKey, List<TrustStatement>> _data;
  _FixtureSource(this._data);

  @override
  final List<SourceError> errors = [];

  @override
  Future<Map<String, List<TrustStatement>>> fetch(Map<String, String?> keys) async {
    final result = <String, List<TrustStatement>>{};
    for (final token in keys.keys) {
      result[token] = _data[IdentityKey(token)] ?? [];
    }
    return result;
  }
}
