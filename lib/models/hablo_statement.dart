import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';

import '../constants.dart';

class HabloStatement extends Statement {
  static void init() {
    Statement.registerFactory('com.hablotengo.contact', _HabloStatementFactory(), HabloStatement, kHabloDomain);
    Statement.registerFactory('com.hablotengo', _HabloStatementFactory(), HabloStatement, kHabloDomain);
  }

  factory HabloStatement(Jsonish jsonish) {
    return HabloStatement._internal(jsonish, jsonish['set']);
  }

  HabloStatement._internal(super.jsonish, super.subject);

  @override
  bool get isClear => false;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    return iTransformer != null ? iTransformer(iToken) : iToken;
  }
}

class _HabloStatementFactory implements StatementFactory {
  static final _HabloStatementFactory _singleton = _HabloStatementFactory._internal();
  _HabloStatementFactory._internal();
  factory _HabloStatementFactory() => _singleton;

  @override
  Statement make(Jsonish j) => HabloStatement(j);
}
