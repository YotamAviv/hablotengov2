import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

/// Reads hablotengo statements from `{delegateKeyToken}/{collectionName}/statements/{id}`.
class HabloStatementSource<T extends Statement> implements StatementSource<T> {
  final FirebaseFirestore _fire;
  final String collectionName;
  final StatementVerifier verifier;
  final ValueListenable<bool>? skipVerify;

  HabloStatementSource(this._fire, this.collectionName,
      {StatementVerifier? verifier, this.skipVerify})
      : verifier = verifier ?? OouVerifier();

  final List<SourceError> _errors = [];

  @override
  List<SourceError> get errors => List.unmodifiable(_errors);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    _errors.clear();
    final Map<String, List<T>> results = {};
    final bool skipCheck = skipVerify?.value ?? false;

    await Future.wait(keys.entries.map((entry) async {
      final String token = entry.key;
      try {
        final ref = _fire
            .collection(token)
            .doc(collectionName)
            .collection('statements');

        final snapshot = await ref.orderBy('time', descending: true).get();
        final List<T> chain = [];

        for (final doc in snapshot.docs) {
          final Json json = doc.data();
          Jsonish jsonish;
          if (!skipCheck) {
            try {
              jsonish = await Jsonish.makeVerify(json, verifier);
            } catch (e) {
              // ignore: avoid_print
              print('HabloStatementSource invalid signature [$token]: $e');
              _errors.add(SourceError('Invalid Signature: $e', token: token, originalError: e));
              continue;
            }
          } else {
            jsonish = Jsonish(json);
          }
          try {
            chain.add(Statement.make(jsonish) as T);
          } catch (e) {
            // ignore: avoid_print
            print('HabloStatementSource parse error [$token]: $e');
            _errors.add(SourceError('Parse error: $e', token: token, originalError: e));
          }
        }
        results[token] = chain;
      } catch (e) {
        // ignore: avoid_print
        print('HabloStatementSource fetch error [$token]: $e');
        _errors.add(SourceError('Fetch error: $e', token: token, originalError: e));
        results[token] = [];
      }
    }));

    return results;
  }
}
