import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_writer.dart';

/// Writes hablotengo statements to `{collectionName}/{issuerToken}/statements/{id}`.
class HabloStatementWriter<T extends Statement> implements StatementWriter<T> {
  final FirebaseFirestore _fire;
  final String collectionName;

  HabloStatementWriter(this._fire, this.collectionName);

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    final String issuerToken = getToken(json['I']);
    final statementsRef = _fire
        .collection(collectionName)
        .doc(issuerToken)
        .collection('statements');

    // Find previous
    final latestSnapshot =
        await statementsRef.orderBy('time', descending: true).limit(1).get();
    String? previousToken;
    DateTime? prevTime;
    if (latestSnapshot.docs.isNotEmpty) {
      final latestDoc = latestSnapshot.docs.first;
      previousToken = latestDoc.id;
      prevTime = DateTime.parse(latestDoc.data()['time']);
    }

    if (previousToken != null) {
      json['previous'] = previousToken;
    }

    final Jsonish jsonish = await Jsonish.makeSign(json, signer);
    final T statement = Statement.make(jsonish) as T;

    await _fire.runTransaction((txn) async {
      final docRef = statementsRef.doc(jsonish.token);
      final doc = await txn.get(docRef);
      if (doc.exists) throw Exception('Statement already exists: ${jsonish.token}');
      if (prevTime != null) {
        final thisTime = DateTime.parse(json['time']!);
        if (!thisTime.isAfter(prevTime)) {
          throw Exception('Timestamp must be after previous statement');
        }
      }
      txn.set(docRef, jsonish.json);
    });

    return statement;
  }
}
