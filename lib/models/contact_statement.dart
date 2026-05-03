import 'package:oneofus_common/jsonish.dart';

const String kHabloStatementType = 'com.hablotengo';

/// Contact info entry: a single tech/value pair with optional flags.
class ContactEntry {
  final String tech;   // e.g. "email", "phone", "whatsapp", "instagram"
  final String value;
  final bool preferred;
  final String visibility; // "default", "permissive", "standard", "strict"
  final double order;      // fractional index: stable identity + display order

  const ContactEntry({
    required this.tech,
    required this.value,
    this.preferred = false,
    this.visibility = 'default',
    this.order = 0.0,
  });

  Json toJson() => {
    'order': order,
    'tech': tech,
    'value': value,
    if (preferred) 'preferred': true,
    if (visibility != 'default') 'visibility': visibility,
  };

  factory ContactEntry.fromJson(Json j, {double defaultOrder = 0.0}) => ContactEntry(
    tech: j['tech'],
    value: j['value'],
    preferred: j['preferred'] ?? false,
    visibility: j['visibility'] ?? 'default',
    order: (j['order'] as num?)?.toDouble() ?? defaultOrder,
  );

  ContactEntry copyWith({
    String? tech,
    String? value,
    bool? preferred,
    String? visibility,
    double? order,
  }) => ContactEntry(
    tech: tech ?? this.tech,
    value: value ?? this.value,
    preferred: preferred ?? this.preferred,
    visibility: visibility ?? this.visibility,
    order: order ?? this.order,
  );
}

/// A contact card: name, notes, and a list of contact entries.
class ContactData {
  final String name;
  final String? notes;
  final List<ContactEntry> entries;

  const ContactData({required this.name, this.notes, this.entries = const []});

  Json toJson() => {
    'name': name,
    if (notes != null) 'notes': notes,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory ContactData.fromJson(Json j) {
    final rawEntries = (j['entries'] as List? ?? []);
    final entries = rawEntries.asMap().entries.map((e) =>
      ContactEntry.fromJson(e.value as Json, defaultOrder: (e.key + 1).toDouble())
    ).toList();
    return ContactData(
      name: j['name'] ?? '',
      notes: j['notes'] as String?,
      entries: entries,
    );
  }
}

// ── Statement JSON builders ──────────────────────────────────────────────────

/// Builds a "set entry" statement JSON (unsigned).
Json buildSetEntryJson({
  required ContactEntry entry,
  required Json delegatePublicKeyJson,
  required String identityToken,
}) => {
  'statement': kHabloStatementType,
  'time': DateTime.now().toUtc().toIso8601String(),
  'I': delegatePublicKeyJson,
  'set': entry.toJson(),
  'with': {'verifiedIdentity': identityToken},
};

/// Builds a "clear entry" statement JSON (unsigned).
Json buildClearEntryJson({
  required double order,
  required Json delegatePublicKeyJson,
  required String identityToken,
}) => {
  'statement': kHabloStatementType,
  'time': DateTime.now().toUtc().toIso8601String(),
  'I': delegatePublicKeyJson,
  'clear': order,
  'with': {'verifiedIdentity': identityToken},
};

/// Builds a "set field" statement JSON for name, notes, or preferences (unsigned).
Json buildSetFieldJson({
  required String field,
  required dynamic value,
  required Json delegatePublicKeyJson,
  required String identityToken,
}) => {
  'statement': kHabloStatementType,
  'time': DateTime.now().toUtc().toIso8601String(),
  'I': delegatePublicKeyJson,
  'set': {'field': field, 'value': value},
  'with': {'verifiedIdentity': identityToken},
};
