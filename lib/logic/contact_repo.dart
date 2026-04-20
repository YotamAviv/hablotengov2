import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hablotengo/constants.dart';
import 'package:hablotengo/logic/delegates.dart';
import 'package:hablotengo/logic/hablo_cloud_functions.dart';
import 'package:hablotengo/logic/hablo_statement_source.dart';
import 'package:hablotengo/logic/proof_builder.dart';
import 'package:hablotengo/logic/trust_pipeline.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/hablo_model.dart';
import 'package:hablotengo/models/override_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/merger.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
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
  final StatementSource<TrustStatement> trustSource;
  final FirebaseFirestore habloFirestore;
  // null = fall back to direct Firestore reads (tests / no-auth mode)
  final HabloCloudFunctions? cloudFunctions;

  ContactRepo({
    required this.trustSource,
    required this.habloFirestore,
    this.cloudFunctions,
  });

  Future<({TrustGraph graph, DelegateResolver delegates, List<ContactEntry> contacts})>
      loadContacts(IdentityKey pov) async {
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

    // Privacy is publicly readable; contact data requires a Cloud Function call.
    final privacySource =
        HabloStatementSource<PrivacyStatement>(habloFirestore, kHabloPrivacyCollection);
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

      VisibilityLevel visibilityLevel = VisibilityLevel.standard;
      if (dkeys.isNotEmpty) {
        final privacyStreams = dkeys.map<Iterable<PrivacyStatement>>(
            (dk) => privacyResults[dk.value] ?? <PrivacyStatement>[]);
        final mergedPrivacy = Merger.merge(privacyStreams);
        if (mergedPrivacy.isNotEmpty) {
          visibilityLevel = mergedPrivacy.first.visibilityLevel;
        }
      }

      entries.add(ContactEntry(
        identity: canonical,
        distance: distance,
        contact: null, // filled in below via Cloud Function
        visibilityLevel: visibilityLevel,
        networkMonikers: networkMonikers[canonical] ?? {},
        canSeeYou: null,
        isYou: canonical == povCanonical,
      ));
    }

    // Fetch contact data: via Cloud Function when available, else direct Firestore
    // (direct reads are used in tests; in production Firestore rules deny client reads).
    Map<IdentityKey, ContactStatement?> contactMap = {};
    if (cloudFunctions != null) {
      final myDelegateToken = signInState.delegate;
      if (myDelegateToken != null) {
        final myDelegateStatement = findDelegateStatement(graph, povCanonical, myDelegateToken);
        if (myDelegateStatement != null) {
          final auth = await signInState.buildDelegateAuth(myDelegateStatement);
          if (auth != null) {
            final futures = <Future<MapEntry<IdentityKey, ContactStatement?>>>[];
            for (final entry in entries) {
              if (entry.isYou) continue;
              final dkeys = canonicalDelegates[entry.identity] ?? [];
              if (dkeys.isEmpty) continue;
              final targetDelegateKey = dkeys.first;
              final targetDelegateStatement =
                  findDelegateStatement(graph, entry.identity, targetDelegateKey.value);
              if (targetDelegateStatement == null) continue;
              final paths = buildProofPaths(graph, entry.identity);
              if (paths == null) continue;
              futures.add(
                cloudFunctions!
                    .getContactInfo(
                      auth: auth,
                      targetDelegateToken: targetDelegateKey.value,
                      targetDelegateStatement: targetDelegateStatement,
                      paths: paths,
                    )
                    .then((c) => MapEntry(entry.identity, c))
                    // ignore: avoid_print
                    .catchError((e) { print('getContactInfo ERROR for ${entry.identity.value}: $e'); return MapEntry(entry.identity, null); }),
              );
            }
            final results = await Future.wait(futures);
            contactMap = Map.fromEntries(results);
          }
        }
      }
    } else {
      // Fallback: direct Firestore reads (for tests / fake-fire mode).
      final contactSource =
          HabloStatementSource<ContactStatement>(habloFirestore, kHabloContactCollection);
      final contactResults = fetchMap.isNotEmpty ? await contactSource.fetch(fetchMap) : {};
      for (final entry in entries) {
        final dkeys = canonicalDelegates[entry.identity] ?? [];
        if (dkeys.isEmpty) continue;
        final streams = dkeys.map<Iterable<ContactStatement>>(
            (dk) => contactResults[dk.value] ?? <ContactStatement>[]);
        final merged = Merger.merge(streams);
        contactMap[entry.identity] = merged.isNotEmpty ? merged.first : null;
      }
    }

    final entriesWithContacts = entries.map((e) {
      if (!contactMap.containsKey(e.identity)) return e;
      return ContactEntry(
        identity: e.identity,
        distance: e.distance,
        contact: contactMap[e.identity],
        visibilityLevel: e.visibilityLevel,
        networkMonikers: e.networkMonikers,
        canSeeYou: null,
        isYou: e.isYou,
      );
    }).toList();

    // Reverse trust: parallel multi-source BFS for each non-self contact
    final reverseFutures = <MapEntry<IdentityKey, Future<bool>>>[];
    for (final entry in entriesWithContacts) {
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

    final finalEntries = entriesWithContacts.map((e) {
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
    StatementSource<TrustStatement> source,
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
      List<DelegateKey> myDelegateKeys, {Json? delegateStatement}) async {
    if (myDelegateKeys.isEmpty) return (contact: null, privacy: null);

    if (cloudFunctions != null && delegateStatement != null) {
      for (final dk in myDelegateKeys) {
        final auth = await signInState.buildDelegateAuth(delegateStatement);
        if (auth == null) continue;
        final result = await cloudFunctions!.getMyCard(auth: auth, delegateToken: dk.value);
        if (result.contact != null || result.privacy != null) {
          final contact = result.contact != null
              ? Statement.make(Jsonish(result.contact!)) as ContactStatement
              : null;
          final privacy = result.privacy != null
              ? Statement.make(Jsonish(result.privacy!)) as PrivacyStatement
              : null;
          return (contact: contact, privacy: privacy);
        }
      }
      return (contact: null, privacy: null);
    }

    // Fallback: direct Firestore reads (fake mode / tests).
    // ignore: avoid_print
    print('loadMyCard: using Firestore fallback (cloudFunctions=$cloudFunctions, delegateStatement=${delegateStatement != null})');
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
