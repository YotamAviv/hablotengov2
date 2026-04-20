import 'package:cloud_functions/cloud_functions.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:hablotengo/models/contact_statement.dart';

class HabloCloudFunctions {
  final FirebaseFunctions _functions;

  HabloCloudFunctions(this._functions);

  Future<void> writeStatement({
    required Json statement,
    required String collection,
  }) async {
    await _functions.httpsCallable('writeStatement').call({
      'statement': statement,
      'collection': collection,
    });
  }

  Future<({Map<String, dynamic>? contact, Map<String, dynamic>? privacy})> getMyCard({
    required Json auth,
    required String delegateToken,
  }) async {
    final result = await _functions.httpsCallable('getMyCard').call({
      'auth': auth,
      'delegateToken': delegateToken,
    });
    final data = result.data as Map<String, dynamic>? ?? {};
    return (
      contact: data['contact'] as Map<String, dynamic>?,
      privacy: data['privacy'] as Map<String, dynamic>?,
    );
  }

  /// Calls the getContactInfo Cloud Function.
  ///
  /// Returns the target's ContactStatement, or null if they have no contact card.
  /// Throws if the proof is insufficient or auth fails.
  Future<ContactStatement?> getContactInfo({
    required Json auth,
    required String targetDelegateToken,
    required Json targetDelegateStatement,
    required List<List<Json>> paths,
  }) async {
    final result = await _functions.httpsCallable('getContactInfo').call({
      'auth': auth,
      'targetDelegateToken': targetDelegateToken,
      'targetDelegateStatement': targetDelegateStatement,
      'paths': paths,
    });
    final data = result.data as Map<String, dynamic>?;
    final contactJson = data?['contact'] as Map<String, dynamic>?;
    if (contactJson == null) return null;
    return Statement.make(Jsonish(contactJson)) as ContactStatement;
  }
}
