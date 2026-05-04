import 'package:oneofus_common/jsonish.dart';

const String kHabloStatementType = 'com.hablotengo';

/// Contact info entry: a single tech/value pair with optional flags.
/// Position in the entries list is the display order — no order field needed.
class ContactEntry {
  final String tech;       // e.g. "email", "phone", "whatsapp", "instagram"
  final String value;
  final bool preferred;
  final String visibility; // "default", "permissive", "standard", "strict"

  const ContactEntry({
    required this.tech,
    required this.value,
    this.preferred = false,
    this.visibility = 'default',
  });

  Json toJson() => {
    'tech': tech,
    'value': value,
    if (preferred) 'preferred': true,
    if (visibility != 'default') 'visibility': visibility,
  };

  factory ContactEntry.fromJson(Json j) => ContactEntry(
    tech: j['tech'],
    value: j['value'],
    preferred: j['preferred'] ?? false,
    visibility: j['visibility'] ?? 'default',
  );

  ContactEntry copyWith({
    String? tech,
    String? value,
    bool? preferred,
    String? visibility,
  }) => ContactEntry(
    tech: tech ?? this.tech,
    value: value ?? this.value,
    preferred: preferred ?? this.preferred,
    visibility: visibility ?? this.visibility,
  );
}

/// A contact card: name, notes, and a list of contact entries.
class ContactData {
  final String name;
  final String? notes;
  final List<ContactEntry> entries;

  const ContactData({required this.name, this.notes, this.entries = const []});

  factory ContactData.fromJson(Json j) {
    final rawEntries = (j['entries'] as List? ?? []);
    final entries = rawEntries.map((e) => ContactEntry.fromJson(e as Json)).toList();
    return ContactData(
      name: j['name'] ?? '',
      notes: j['notes'] as String?,
      entries: entries,
    );
  }
}

// ── Statement JSON builders ──────────────────────────────────────────────────

/// Builds a snapshot statement: the full contact card (name, notes, entries) in one `set`.
/// One statement per save — no per-field diffing, no per-entry statements.
Json buildContactSnapshot({
  required ContactData contact,
  required Json delegatePublicKeyJson,
  required String identityToken,
}) => {
  'statement': kHabloStatementType,
  'time': DateTime.now().toUtc().toIso8601String(),
  'I': delegatePublicKeyJson,
  'set': {
    'name': contact.name,
    if (contact.notes != null) 'notes': contact.notes,
    'entries': contact.entries.map((e) => e.toJson()).toList(),
  },
  'with': {'verifiedIdentity': identityToken},
};

/// Builds a "set" statement for a single settings field (showEmptyCards, defaultStrictness, etc.).
/// Settings changes are infrequent and stay as individual statements — they are accumulated
/// alongside contact snapshots during replay.
Json buildSetFieldJson({
  required String field,
  required dynamic value,
  required Json delegatePublicKeyJson,
  required String identityToken,
}) => {
  'statement': kHabloStatementType,
  'time': DateTime.now().toUtc().toIso8601String(),
  'I': delegatePublicKeyJson,
  'set': {field: value},
  'with': {'verifiedIdentity': identityToken},
};
