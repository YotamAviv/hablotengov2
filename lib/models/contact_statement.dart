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
  /// [{address, preferred}]
  final List<Map<String, dynamic>> emails;
  /// [{number, preferred}]
  final List<Map<String, dynamic>> phones;
  /// {key: [{handle, preferred}]}
  final Map<String, List<Map<String, dynamic>>> contactPrefs;
  /// {key: string}
  final Map<String, String> socialAccounts;
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
        emails = _parseEmailList(jsonish['emails']),
        phones = _parsePhoneList(jsonish['phone'], jsonish['phones']),
        contactPrefs = _parseContactPrefs(jsonish['contactPrefs']),
        socialAccounts = _parseSocialAccounts(jsonish['socialAccounts']),
        website = jsonish['website'],
        other = jsonish['other'],
        super(jsonish, null);

  static List<Map<String, dynamic>> _parseEmailList(dynamic raw) {
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw);
  }

  /// Handles old format (phone: string) and new format (phones: [{number, preferred}]).
  static List<Map<String, dynamic>> _parsePhoneList(dynamic oldPhone, dynamic newPhones) {
    if (newPhones != null) return List<Map<String, dynamic>>.from(newPhones);
    if (oldPhone is String && oldPhone.isNotEmpty) {
      return [{'number': oldPhone, 'preferred': false}];
    }
    return [];
  }

  /// Handles old format ({key: {handle, preferred}}) and new ({key: [{handle, preferred}]}).
  static Map<String, List<Map<String, dynamic>>> _parseContactPrefs(dynamic raw) {
    if (raw == null) return {};
    final map = Map<String, dynamic>.from(raw);
    return map.map((k, v) {
      if (v is List) return MapEntry(k, List<Map<String, dynamic>>.from(v));
      if (v is Map) return MapEntry(k, [Map<String, dynamic>.from(v)]);
      return MapEntry(k, <Map<String, dynamic>>[]);
    });
  }

  static Map<String, String> _parseSocialAccounts(dynamic raw) {
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw).map((k, v) => MapEntry(k, v.toString()));
  }

  static Map<String, dynamic> buildJson({
    required Map<String, dynamic> iJson,
    String? name,
    List<Map<String, dynamic>> emails = const [],
    List<Map<String, dynamic>> phones = const [],
    Map<String, List<Map<String, dynamic>>> contactPrefs = const {},
    Map<String, String> socialAccounts = const {},
    String? website,
    String? other,
  }) {
    return {
      'statement': 'org.hablotengo.contact',
      'I': iJson,
      'time': clock.nowIso,
      if (name != null) 'name': name,
      'emails': emails,
      'phones': phones,
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
