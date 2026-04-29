// TODO: Consider factoring with the similar Labeler in nerdster14/lib/logic/labeler.dart.
// That version also handles delegate keys (homer@nerdster.org style); this one is identity-only.

import 'package:nerdster_common/trust_graph.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';

/// Assigns human-readable monikers to identity keys based on a trust graph.
///
/// One entry per canonical identity (equivalence group). Old/replaced keys
/// get prime notation (e.g. "Homer'"). Name collisions get a numeric suffix
/// (e.g. "Mom (2)").
class Labeler {
  final TrustGraph graph;

  final Map<IdentityKey, String> _identityToName = {};
  final Map<IdentityKey, Set<String>> _identityToAllNames = {};
  final Set<String> _usedNames = {};

  Labeler(this.graph) {
    _computeLabels();
  }

  void _computeLabels() {
    final Map<IdentityKey, List<TrustStatement>> incomingByIdentity = {};
    for (final IdentityKey issuer in graph.edges.keys) {
      for (final TrustStatement s in graph.edges[issuer]!) {
        final IdentityKey subject = graph.resolveIdentity(IdentityKey(s.subjectToken));
        incomingByIdentity.putIfAbsent(subject, () => []).add(s);
        if (s.moniker != null) {
          _identityToAllNames.putIfAbsent(subject, () => {}).add(s.moniker!);
        }
      }
    }

    for (final IdentityKey token in graph.orderedKeys) {
      if (_identityToName.containsKey(token)) continue;

      final IdentityKey identity = graph.resolveIdentity(token);

      String baseName;
      if (_identityToName.containsKey(identity)) {
        baseName = _identityToName[identity]!;
      } else {
        final List<TrustStatement> statements = incomingByIdentity[identity] ?? [];
        statements.sort((a, b) {
          final int distA = graph.distances[IdentityKey(a.iToken)] ?? 999;
          final int distB = graph.distances[IdentityKey(b.iToken)] ?? 999;
          return distA.compareTo(distB);
        });

        String? bestMoniker;
        for (final TrustStatement s in statements) {
          if (s.moniker != null) {
            bestMoniker = s.moniker;
            break;
          }
        }

        if (bestMoniker == null) continue;

        baseName = _makeUnique(bestMoniker, isOld: false);
        _identityToName[identity] = baseName;
        _usedNames.add(baseName);
      }

      if (token != identity) {
        final label = _makeUnique(baseName, isOld: true);
        _identityToName[token] = label;
        _usedNames.add(label);
      }
    }
  }

  String _makeUnique(String name, {bool isOld = false}) {
    if (!isOld) {
      if (!_usedNames.contains(name)) return name;
      for (int i = 2;; i++) {
        final alt = '$name ($i)';
        if (!_usedNames.contains(alt)) return alt;
      }
    } else {
      String candidate = name;
      while (true) {
        candidate = "$candidate'";
        if (!_usedNames.contains(candidate)) return candidate;
      }
    }
  }

  String getIdentityLabel(IdentityKey key) {
    return _identityToName[key] ?? (key.value.length > 8 ? key.value.substring(0, 8) : key.value);
  }

  List<String> getAllLabels(IdentityKey key) {
    final identity = graph.resolveIdentity(key);
    return _identityToAllNames[identity]?.toList() ?? [];
  }
}
