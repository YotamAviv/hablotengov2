import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:hablotengo/models/hablo_model.dart';

/// Converts the node-disjoint paths stored in a TrustGraph into signed trust
/// statement JSON lists suitable for the getContactInfo Cloud Function.
///
/// Returns null if no path to [target] exists.
List<List<Json>>? buildProofPaths(TrustGraph graph, IdentityKey target) {
  final pathNodes = graph.paths[target];
  if (pathNodes == null || pathNodes.isEmpty) return null;
  return pathNodes.map((nodes) => _nodesToStatements(graph, nodes)).toList();
}

List<Json> _nodesToStatements(TrustGraph graph, List<IdentityKey> nodes) {
  final stmts = <Json>[];
  for (int i = 0; i < nodes.length - 1; i++) {
    final issuer = nodes[i];
    final subjectToken = nodes[i + 1].value;
    final stmt = (graph.edges[issuer] ?? []).firstWhere(
      (s) => s.verb == TrustVerb.trust && s.subjectToken == subjectToken,
    );
    stmts.add(stmt.json);
  }
  return stmts;
}

/// Finds the signed delegate statement in the graph proving [identity] delegated
/// to the key with [delegateToken].  Returns null if not found.
Json? findDelegateStatement(
    TrustGraph graph, IdentityKey identity, String delegateToken) {
  for (final stmt in graph.edges[identity] ?? <TrustStatement>[]) {
    if (stmt.verb == TrustVerb.delegate && stmt.subjectToken == delegateToken) {
      return stmt.json;
    }
  }
  return null;
}
