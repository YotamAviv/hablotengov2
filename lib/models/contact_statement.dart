import 'package:oneofus_common/jsonish.dart';

/// Contact info entry: a single tech/value pair with optional flags.
class ContactEntry {
  final String tech;   // e.g. "email", "phone", "whatsapp", "instagram"
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
}

/// A contact statement: name, notes, and a list of contact entries.
/// Signed by a delegate key, stored in hablotengo_contact collection.
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

  factory ContactData.fromJson(Json j) => ContactData(
    name: j['name'] ?? '',
    notes: j['notes'],
    entries: (j['entries'] as List? ?? [])
        .map((e) => ContactEntry.fromJson(e as Json))
        .toList(),
  );
}
