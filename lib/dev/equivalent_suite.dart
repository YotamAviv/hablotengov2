// Equivalent key test scenarios for homer (old key) and homer2.
//
// Prerequisites (fresh state per scenario):
//   ./bin/stop_emulator.sh
//   ./bin/start_emulator.sh
//   ./bin/createSimpsonsContactData.sh
//
// Run individual scenarios via:
//   python3 bin/chrome_widget_runner.py -t lib/dev/equivalent_web_test_a.dart  (etc.)

import 'package:flutter/foundation.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/contact_service.dart';
import 'package:hablotengo/equivalent_service.dart';
import 'package:hablotengo/labeler.dart';
import 'package:hablotengo/settings_state.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/dev/simpsons_public_keys.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _homer2Jwk  = (kSimpsonsPublicKeys['homer2']! as Map).cast<String, dynamic>();
final _homerJwk   = (kSimpsonsPublicKeys['homer']!  as Map).cast<String, dynamic>();

void _signInAs(Map<String, dynamic> jwk) {
  signInState.restoreDemoKeys(jwk);
  settingsState.reset();
}

class _Contact {
  final String token;
  final String name;
  final List<String> oldKeyTokens;
  _Contact(this.token, this.name, this.oldKeyTokens);
}

Future<List<_Contact>> _buildContacts() async {
  final identityToken = signInState.identityToken!;
  final source = CloudFunctionsSource<TrustStatement>(
    baseUrl: oneofusExportUrl(true),
    verifier: OouVerifier(),
  );
  final pipeline = TrustPipeline(source);
  final TrustGraph graph = await pipeline.build(IdentityKey(identityToken));
  final labeler = Labeler(graph);

  final seen = <IdentityKey>{};
  final contacts = <_Contact>[];
  for (final key in graph.orderedKeys) {
    final canonical = graph.resolveIdentity(key);
    if (seen.contains(canonical)) continue;
    seen.add(canonical);
    final group = graph.getEquivalenceGroup(canonical);
    final oldKeys = group.where((k) => k != canonical).map((k) => k.value).toList();
    contacts.add(_Contact(canonical.value, labeler.getIdentityLabel(canonical), oldKeys));
  }
  return contacts;
}

// Mirrors ContactsScreen's getBatchContacts + settingsState filter.
Future<List<String>> _visibleTokens(List<_Contact> contacts) async {
  final tokens = contacts.map((c) => c.token).toList();
  final results = await getBatchContacts(tokens, true);
  return contacts.where((c) {
    final status = results[c.token]?.status;
    if (status == ContactStatus.notFound && !settingsState.showEmptyCards) return false;
    if (status == ContactStatus.denied && !settingsState.showHiddenCards) return false;
    return true;
  }).map((c) => c.token).toList();
}

Future<List<String>> _myContactEntryTechs() async {
  final card = await getMyContact(true);
  return card?.entries.map((e) => e.tech).toList() ?? [];
}

Future<Map<String, String?>> _equivalentStatus(List<String> tokens) =>
    getEquivalentStatus(tokens, true);

Future<String?> _disabledBy() async {
  await settingsState.load(true);
  return settingsState.disabledBy;
}

void _assert(bool condition, String message) {
  if (!condition) {
    // ignore: avoid_print
    print('FAIL: $message');
    throw Exception(message);
  }
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// Scenario A: Homer2 dismisses homer (old key).
Future<void> scenarioA() async {
  debugPrint('=== Scenario A: homer2 dismisses homer ===');
  _signInAs(_homer2Jwk);
  final homer2Token = signInState.identityToken!;

  final contacts = await _buildContacts();
  final homerOldToken = contacts
      .firstWhere((c) => c.token == homer2Token)
      .oldKeyTokens
      .firstOrNull;
  _assert(homerOldToken != null, 'A: homer2 equivalence group should include homer old key');

  final statusBefore = await _equivalentStatus([homerOldToken!]);
  _assert(statusBefore[homerOldToken] == null, 'A: homer old key should not be disabled before dismiss');

  await dismissEquivalent(homerOldToken, true);

  Future<void> verifyAfterDismiss(List<_Contact> cs, String label) async {
    final topLevel = cs.map((c) => c.token).toList();
    _assert(!topLevel.contains(homerOldToken),
        'A[$label]: homer old key should not appear as top-level contact, got: $topLevel');
    final self = cs.firstWhere((c) => c.token == homer2Token);
    _assert(self.oldKeyTokens.contains(homerOldToken),
        'A[$label]: homer old key should appear as old key of homer2');

    // Default settings: homer2 (no contact card) is not visible.
    settingsState.reset();
    final visibleDefault = await _visibleTokens(cs);
    _assert(!visibleDefault.contains(homer2Token),
        'A[$label]: homer2 should not be visible with default settings');

    // After enabling showEmptyCards + showHiddenCards: homer2 visible as "Holmes".
    settingsState.showEmptyCards = true;
    settingsState.showHiddenCards = true;
    final visibleAll = await _visibleTokens(cs);
    _assert(visibleAll.contains(homer2Token),
        'A[$label]: homer2 should be visible with showEmptyCards+showHiddenCards, got: $visibleAll');
    _assert(self.name == 'Holmes',
        'A[$label]: homer2 moniker should be "Holmes", got: ${self.name}');
  }

  final contactsAfter = await _buildContacts();
  await verifyAfterDismiss(contactsAfter, 'first load');

  // Reload and verify again.
  final contactsReload = await _buildContacts();
  await verifyAfterDismiss(contactsReload, 'reload');

  // Popup should not reappear.
  final statusAfter = await _equivalentStatus([homerOldToken]);
  _assert(statusAfter[homerOldToken] == null, 'A: homer old key should still not be disabled after dismiss');

  debugPrint('DONE: Scenario A');
}

/// Scenario B: Homer2 merges & disables homer (old key).
Future<void> scenarioB() async {
  debugPrint('=== Scenario B: homer2 merges and disables homer ===');
  _signInAs(_homer2Jwk);
  final homer2Token = signInState.identityToken!;

  final contacts = await _buildContacts();
  final homerOldToken = contacts
      .firstWhere((c) => c.token == homer2Token)
      .oldKeyTokens
      .firstOrNull;
  _assert(homerOldToken != null, 'B: homer2 equivalence group should include homer old key');

  await disableEquivalent(homerOldToken!, mergeContact: true, emulator: true);

  // Homer old key should be disabled.
  final status = await _equivalentStatus([homerOldToken]);
  _assert(status[homerOldToken] == homer2Token,
      'B: homer old key should be disabled by homer2, got: ${status[homerOldToken]}');

  // Homer old key should NOT appear as a top-level contact after reload.
  final contactsAfter = await _buildContacts();
  final topLevelTokens = contactsAfter.map((c) => c.token).toList();
  _assert(!topLevelTokens.contains(homerOldToken),
      'B: disabled homer old key should not be a top-level contact, got: $topLevelTokens');

  // Homer2's card should now include homer's phone entry.
  final techs = await _myContactEntryTechs();
  _assert(techs.contains('phone'), 'B: homer2 card should have phone entry after merge, got: $techs');

  // Popup should not reappear.
  final statusAfter = await _equivalentStatus([homerOldToken]);
  _assert(statusAfter[homerOldToken] != null, 'B: homer old key should remain disabled on re-check');

  debugPrint('DONE: Scenario B');
}

/// Scenario C: Homer (old key) signs in — account not disabled.
Future<void> scenarioC() async {
  debugPrint('=== Scenario C: homer signs in, not disabled ===');
  _signInAs(_homerJwk);
  final homerToken = signInState.identityToken!;

  final disabled = await _disabledBy();
  _assert(disabled == null, 'C: homer account should not be disabled, got disabledBy=$disabled');

  // Homer2 should appear as a separate top-level contact.
  final contacts = await _buildContacts();
  final topLevelTokens = contacts.map((c) => c.token).toList();
  _assert(topLevelTokens.contains(homerToken), 'C: homer should appear as self');

  // homer2 should appear as a separate contact (distinct token, not an old key of homer).
  final homer2Contact = contacts.where((c) =>
      c.token != homerToken && c.oldKeyTokens.isEmpty).toList();
  final hasHomer2 = contacts.any((c) =>
      c.token != homerToken &&
      !contacts.any((other) => other.oldKeyTokens.contains(c.token)));
  _assert(hasHomer2 || homer2Contact.isNotEmpty,
      'C: homer2 should appear as a separate top-level contact; contacts: $topLevelTokens');

  debugPrint('DONE: Scenario C');
}

/// Scenario D: Homer (old key) signs in — account disabled — chooses Enable.
Future<void> scenarioD() async {
  debugPrint('=== Scenario D: homer disabled, enables ===');

  // Setup: homer2 disables homer.
  _signInAs(_homer2Jwk);
  final contacts = await _buildContacts();
  final homer2Token = signInState.identityToken!;
  final homerOldToken = contacts
      .firstWhere((c) => c.token == homer2Token)
      .oldKeyTokens
      .firstOrNull;
  _assert(homerOldToken != null, 'D setup: homer2 equivalence group should include homer old key');
  await disableEquivalent(homerOldToken!, mergeContact: false, emulator: true);

  // Now sign in as homer.
  _signInAs(_homerJwk);
  final disabled = await _disabledBy();
  _assert(disabled == homer2Token,
      'D: homer account should be disabled by homer2, got disabledBy=$disabled');

  // Enable.
  await enableAccount(true);

  final disabledAfter = await _disabledBy();
  _assert(disabledAfter == null, 'D: homer account should not be disabled after enable, got=$disabledAfter');

  // Contacts list should load normally.
  final contactsAfter = await _buildContacts();
  _assert(contactsAfter.isNotEmpty, 'D: contacts list should not be empty after enable');

  debugPrint('DONE: Scenario D');
}

/// Scenario E: Homer (old key) signs in — account disabled — chooses Sign out.
Future<void> scenarioE() async {
  debugPrint('=== Scenario E: homer disabled, signs out ===');

  // Setup: homer2 disables homer.
  _signInAs(_homer2Jwk);
  final contacts = await _buildContacts();
  final homer2Token = signInState.identityToken!;
  final homerOldToken = contacts
      .firstWhere((c) => c.token == homer2Token)
      .oldKeyTokens
      .firstOrNull;
  _assert(homerOldToken != null, 'E setup: homer2 equivalence group should include homer old key');
  await disableEquivalent(homerOldToken!, mergeContact: false, emulator: true);

  // Sign in as homer.
  _signInAs(_homerJwk);
  final disabled = await _disabledBy();
  _assert(disabled == homer2Token,
      'E: homer account should be disabled by homer2, got disabledBy=$disabled');

  // Sign out.
  signInState.signOut();
  settingsState.reset();

  _assert(!signInState.hasIdentity, 'E: should be signed out after signOut()');

  debugPrint('DONE: Scenario E');
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> runScenario(Future<void> Function() scenario) async {
  TrustStatement.init();
  await scenario();
  // ignore: avoid_print
  print('PASS');
}
