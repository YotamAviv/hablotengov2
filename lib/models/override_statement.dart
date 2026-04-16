import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

enum OverrideVerb { allow, block }

class OverrideStatement extends Statement {
  static final Map<String, OverrideStatement> _cache = {};

  static void clearCache() => _cache.clear();

  static void init() {
    Statement.registerFactory('org.hablotengo.override', _OverrideFactory(), OverrideStatement);
  }

  final OverrideVerb verb;

  DelegateKey get iKey => DelegateKey(getToken(this.i));
  IdentityKey get subjectIdentity => IdentityKey(subjectToken);

  @override
  bool get isClear => false;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final canonI = iTransformer != null ? iTransformer(iToken) : iToken;
    final canonS = sTransformer != null ? sTransformer(subjectToken) : subjectToken;
    return '$canonI:$canonS';
  }

  factory OverrideStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;
    final s = OverrideStatement._make(jsonish);
    _cache[jsonish.token] = s;
    return s;
  }

  OverrideStatement._make(Jsonish jsonish)
      : verb = jsonish['allow'] != null ? OverrideVerb.allow : OverrideVerb.block,
        super(jsonish, jsonish['allow'] ?? jsonish['block']);

  static Map<String, dynamic> buildJson({
    required Map<String, dynamic> iJson,
    required OverrideVerb verb,
    required Map<String, dynamic> subjectJson,
  }) {
    return {
      'statement': 'org.hablotengo.override',
      'I': iJson,
      'time': clock.nowIso,
      verb.name: subjectJson,
    };
  }
}

class _OverrideFactory implements StatementFactory {
  @override
  Statement make(Jsonish j) => OverrideStatement(j);
}
