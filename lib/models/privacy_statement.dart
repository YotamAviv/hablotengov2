import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

enum VisibilityLevel { permissive, standard, strict }

/// Signed statement by a delegate key declaring the owner's contact visibility level.
/// Written to `{delegateToken}/hablotengo_privacy/statements/{token}`.
/// The `getContactInfo` CF reads the latest to decide if the requester's trust proof
/// is sufficient. Latest statement wins (ordered by time desc).
class PrivacyStatement extends Statement {
  static final Map<String, PrivacyStatement> _cache = {};

  static void clearCache() => _cache.clear();

  static void init() {
    Statement.registerFactory('org.hablotengo.privacy', _PrivacyFactory(), PrivacyStatement);
  }

  final VisibilityLevel visibilityLevel;

  DelegateKey get iKey => DelegateKey(getToken(this.i));

  @override
  bool get isClear => false;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final canonI = iTransformer != null ? iTransformer(iToken) : iToken;
    return '$canonI:privacy';
  }

  factory PrivacyStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;
    final s = PrivacyStatement._make(jsonish);
    _cache[jsonish.token] = s;
    return s;
  }

  PrivacyStatement._make(Jsonish jsonish)
      : visibilityLevel = VisibilityLevel.values.byName(jsonish['visibilityLevel'] ?? 'standard'),
        super(jsonish, jsonish['visibilityLevel']);

  static Map<String, dynamic> buildJson({
    required Map<String, dynamic> iJson,
    required VisibilityLevel level,
  }) {
    return {
      'statement': 'org.hablotengo.privacy',
      'I': iJson,
      'time': clock.nowIso,
      'visibilityLevel': level.name,
    };
  }
}

class _PrivacyFactory implements StatementFactory {
  @override
  Statement make(Jsonish j) => PrivacyStatement(j);
}
