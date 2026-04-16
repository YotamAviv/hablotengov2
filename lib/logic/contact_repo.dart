import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/logic/delegates.dart';
import 'package:hablotengo/logic/hablo_statement_source.dart';
import 'package:hablotengo/logic/trust_pipeline.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/hablo_model.dart';
import 'package:hablotengo/models/override_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/merger.dart';
import 'package:oneofus_common/trust_statement.dart';

class ContactEntry {
  final IdentityKey identity;
  final int distance;
  final ContactStatement? contact;
  final VisibilityLevel visibilityLevel;
  /// Monikers from all trust statements in the PoV's graph pointing to this person.
  final Set<String> networkMonikers;
  /// null = not yet computed, true = can see your card, false = cannot
  final bool? canSeeYou;
  final bool isYou;

  const ContactEntry({
    required this.identity,
    required this.distance,
    this.contact,
    this.visibilityLevel = VisibilityLevel.standard,
    this.networkMonikers = const {},
    this.canSeeYou,
    this.isYou = false,
  });

  ContactEntry withCanSeeYou(bool value) => ContactEntry(
    identity: identity,
    distance: distance,
    contact: contact,
    visibilityLevel: visibilityLevel,
    networkMonikers: networkMonikers,
    canSeeYou: value,
    isYou: isYou,
  );

  /// Best display name: self-given name, then PoV's own moniker, then any network moniker.
  String displayName(IdentityKey pov, TrustGraph graph) {
    if (contact?.name != null && contact!.name!.isNotEmpty) return contact!.name!;
    // PoV's own moniker for this person
    for (final stmt in graph.edges[pov] ?? <TrustStatement>[]) {
      if (stmt.verb == TrustVerb.trust &&
          graph.resolveIdentity(IdentityKey(stmt.subjectToken)) == identity &&
          stmt.moniker != null) {
        return stmt.moniker!;
      }
    }
    if (networkMonikers.isNotEmpty) return networkMonikers.first;
    return '${identity.value.substring(0, 8)}…';
  }

  /// All names this person is known by (for search).
  Set<String> allNames(IdentityKey pov, TrustGraph graph) {
    final names = <String>{};
    if (contact?.name != null && contact!.name!.isNotEmpty) names.add(contact!.name!);
    names.addAll(networkMonikers);
    return names;
  }
}

class ContactRepo {
  final FirebaseFirestore oneofusFirestore;
  final FirebaseFirestore habloFirestore;

  ContactRepo({required this.oneofusFirestore, required this.habloFirestore});

  Future<({TrustGraph graph, DelegateResolver delegates, List<ContactEntry> contacts})>
      loadContacts(IdentityKey pov) async {
    final trustSource = DirectFirestoreSource<TrustStatement>(oneofusFirestore);
    final pipeline = TrustPipeline(trustSource);
    final graph = await pipeline.build(pov);

    final delegates = DelegateResolver(graph);
    for (final identity in graph.distances.keys) {
      delegates.resolveForIdentity(identity);
    }

    final canonicalDelegates = <IdentityKey, List<DelegateKey>>{};
    for (final identity in graph.orderedKeys) {
      final canonical = graph.resolveIdentity(identity);
      if (!canonicalDelegates.containsKey(canonical)) {
        final dkeys = delegates.getDelegatesForIdentity(canonical)
            .where((dk) => delegates.getDomainForDelegate(dk) == kHablotengo)
            .toList();
        canonicalDelegates[canonical] = dkeys;
      }
    }

    final allDelegateTokens = canonicalDelegates.values
        .expand((list) => list).map((k) => k.value).toSet();
    final fetchMap = {for (final t in allDelegateTokens) t: null};

    final contactSource =
        HabloStatementSource<ContactStatement>(habloFirestore, kHabloContactCollection);
    final privacySource =
        HabloStatementSource<PrivacyStatement>(habloFirestore, kHabloPrivacyCollection);

    final contactResults = fetchMap.isNotEmpty ? await contactSource.fetch(fetchMap) : {};
    final privacyResults = fetchMap.isNotEmpty ? await privacySource.fetch(fetchMap) : {};

    // Collect network monikers: for each canonical, find all monikers in graph edges pointing to it
    final networkMonikers = <IdentityKey, Set<String>>{};
    for (final stmtList in graph.edges.values) {
      for (final stmt in stmtList) {
        if (stmt.verb != TrustVerb.trust || stmt.moniker == null) continue;
        final canonical = graph.resolveIdentity(IdentityKey(stmt.subjectToken));
        networkMonikers.putIfAbsent(canonical, () => {}).add(stmt.moniker!);
      }
    }

    final seen = <IdentityKey>{};
    final List<ContactEntry> entries = [];
    final povCanonical = graph.resolveIdentity(pov);

    for (final identity in graph.orderedKeys) {
      final canonical = graph.resolveIdentity(identity);
      if (seen.contains(canonical)) continue;
      seen.add(canonical);

      final distance = graph.distances[canonical] ?? graph.distances[identity] ?? 999;
      final dkeys = canonicalDelegates[canonical] ?? [];

      ContactStatement? latestContact;
      if (dkeys.isNotEmpty) {
        final streams = dkeys.map<Iterable<ContactStatement>>(
            (dk) => contactResults[dk.value] ?? <ContactStatement>[]);
        final merged = Merger.merge(streams);
        if (merged.isNotEmpty) latestContact = merged.first as ContactStatement;
      }

      VisibilityLevel visibilityLevel = VisibilityLevel.standard;
      if (dkeys.isNotEmpty) {
        final privacyStreams = dkeys.map<Iterable<PrivacyStatement>>(
            (dk) => privacyResults[dk.value] ?? <PrivacyStatement>[]);
        final mergedPrivacy = Merger.merge(privacyStreams);
        if (mergedPrivacy.isNotEmpty) {
          visibilityLevel = (mergedPrivacy.first as PrivacyStatement).visibilityLevel;
        }
      }

      entries.add(ContactEntry(
        identity: canonical,
        distance: distance,
        contact: latestContact,
        visibilityLevel: visibilityLevel,
        networkMonikers: networkMonikers[canonical] ?? {},
        canSeeYou: null,
        isYou: canonical == povCanonical,
      ));
    }

    // Reverse trust: parallel multi-source BFS for each non-self contact
    final reverseFutures = <MapEntry<IdentityKey, Future<bool>>>[];
    for (final entry in entries) {
      if (entry.isYou) continue;
      reverseFutures.add(MapEntry(
        entry.identity,
        _canSeeYou(entry.identity, povCanonical, trustSource, entry.visibilityLevel),
      ));
    }

    final reverseResults = await Future.wait(
      reverseFutures.map((e) => e.value.then((r) => MapEntry(e.key, r))),
    );
    final canSeeMap = Map.fromEntries(reverseResults);

    final finalEntries = entries.map((e) {
      if (e.isYou) return e;
      return e.withCanSeeYou(canSeeMap[e.identity] ?? false);
    }).toList();

    return (graph: graph, delegates: delegates, contacts: finalEntries);
  }

  /// Returns true if [a] (the PoV) can see [b]'s card — i.e., [b] trusts [a]
  /// at the level required by [b]'s visibilityLevel.
  Future<bool> _canSeeYou(
    IdentityKey b,
    IdentityKey a,
    DirectFirestoreSource<TrustStatement> source,
    VisibilityLevel level,
  ) async {
    final req = switch (level) {
      VisibilityLevel.permissive => TrustPipeline.permissivePathRequirement,
      VisibilityLevel.standard => TrustPipeline.defaultPathRequirement,
      VisibilityLevel.strict => TrustPipeline.strictPathRequirement,
    };
    final bGraph = await TrustPipeline(source, pathRequirement: req).build(b);
    return bGraph.distances.keys.any((k) => bGraph.resolveIdentity(k) == a);
  }

  Future<({ContactStatement? contact, PrivacyStatement? privacy})> loadMyCard(
      List<DelegateKey> myDelegateKeys) async {
    if (myDelegateKeys.isEmpty) return (contact: null, privacy: null);

    final contactSource =
        HabloStatementSource<ContactStatement>(habloFirestore, kHabloContactCollection);
    final privacySource =
        HabloStatementSource<PrivacyStatement>(habloFirestore, kHabloPrivacyCollection);

    final fetchMap = {for (final k in myDelegateKeys) k.value: null};
    final contactResults = await contactSource.fetch(fetchMap);
    final privacyResults = await privacySource.fetch(fetchMap);

    final merged = Merger.merge(
        myDelegateKeys.map((k) => (contactResults[k.value] ?? <ContactStatement>[])));
    final mergedPrivacy = Merger.merge(
        myDelegateKeys.map((k) => (privacyResults[k.value] ?? <PrivacyStatement>[])));

    return (
      contact: merged.isNotEmpty ? merged.first : null,
      privacy: mergedPrivacy.isNotEmpty ? mergedPrivacy.first : null,
    );
  }

  Future<List<OverrideStatement>> loadOverrides(List<DelegateKey> myDelegateKeys) async {
    if (myDelegateKeys.isEmpty) return [];
    final overrideSource =
        HabloStatementSource<OverrideStatement>(habloFirestore, kHabloOverrideCollection);
    final fetchMap = {for (final k in myDelegateKeys) k.value: null};
    final results = await overrideSource.fetch(fetchMap);
    return myDelegateKeys
        .expand((k) => results[k.value] ?? <OverrideStatement>[])
        .toList();
  }
}
