import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';
import 'package:hablotengo/constants.dart';

class ContactStatement extends Statement {
  static final Map<String, ContactStatement> _cache = {};

  static void clearCache() => _cache.clear();

  static void init() {
    Statement.registerFactory(
        'org.hablotengo.contact', _ContactFactory(), ContactStatement, kHablotengo);
  }

  final String? name;
  final List<Map<String, dynamic>> emails;
  final String? phone;
  final Map<String, dynamic> contactPrefs;
  final Map<String, dynamic> socialAccounts;
  final String? website;
  final String? other;

  DelegateKey get iKey => DelegateKey(getToken(this.i));

  @override
  bool get isClear => false;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final canonI = iTransformer != null ? iTransformer(iToken) : iToken;
    return '$canonI:contact';
  }

  factory ContactStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;
    final s = ContactStatement._make(jsonish);
    _cache[jsonish.token] = s;
    return s;
  }

  ContactStatement._make(Jsonish jsonish)
      : name = jsonish['name'],
        emails = List<Map<String, dynamic>>.from(jsonish['emails'] ?? []),
        phone = jsonish['phone'],
        contactPrefs = Map<String, dynamic>.from(jsonish['contactPrefs'] ?? {}),
        socialAccounts = Map<String, dynamic>.from(jsonish['socialAccounts'] ?? {}),
        website = jsonish['website'],
        other = jsonish['other'],
        super(jsonish, null);

  static Map<String, dynamic> buildJson({
    required Map<String, dynamic> iJson,
    String? name,
    List<Map<String, dynamic>> emails = const [],
    String? phone,
    Map<String, dynamic> contactPrefs = const {},
    Map<String, dynamic> socialAccounts = const {},
    String? website,
    String? other,
  }) {
    return {
      'statement': 'org.hablotengo.contact',
      'I': iJson,
      'time': clock.nowIso,
      if (name != null) 'name': name,
      'emails': emails,
      if (phone != null) 'phone': phone,
      'contactPrefs': contactPrefs,
      'socialAccounts': socialAccounts,
      if (website != null) 'website': website,
      if (other != null) 'other': other,
    };
  }
}

class _ContactFactory implements StatementFactory {
  @override
  Statement make(Jsonish j) => ContactStatement(j);
}
