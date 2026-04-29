import 'package:flutter/foundation.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'package:hablotengo/constants.dart';
import 'package:hablotengo/labeler.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:hablotengo/dev/simpsons_public_keys.dart';

/// Verifies that Lisa's trust graph produces expected names.
/// Prints PASS or FAIL — consumed by chrome_widget_runner.py.
Future<void> runContactsVerification() async {
  TrustStatement.init();

  final lisaKey = (kSimpsonsPublicKeys['lisa']! as Map).cast<String, dynamic>();
  signInState.restoreKeys(lisaKey);
  final identityToken = signInState.identityToken!;
  debugPrint('contacts_suite: signing in as Lisa ($identityToken)');

  final source = CloudFunctionsSource<TrustStatement>(
    baseUrl: oneofusExportUrl(true),
    verifier: OouVerifier(),
  );
  final pipeline = TrustPipeline(source);
  final graph = await pipeline.build(IdentityKey(identityToken));
  debugPrint('contacts_suite: trusted tokens=${graph.orderedKeys.length}');

  final labeler = Labeler(graph);
  final seen = <IdentityKey>{};
  final names = <String>[];
  for (final key in graph.orderedKeys) {
    final canonical = graph.resolveIdentity(key);
    if (canonical == graph.pov) continue;
    if (seen.contains(canonical)) continue;
    seen.add(canonical);
    final name = labeler.getIdentityLabel(canonical);
    names.add(name);

    final group = graph.getEquivalenceGroup(canonical);
    for (final old in group.where((k) => k != canonical)) {
      names.add(labeler.getIdentityLabel(old));
    }
  }

  debugPrint('contacts_suite: names=$names');

  // Mom must appear
  _assert(names.contains('Mom'), 'Expected "Mom" in names, got: $names');

  // Homer must appear exactly once as a canonical name
  final homerCount = names.where((n) => n == 'Homer').length;
  _assert(homerCount == 1, 'Expected "Homer" exactly once, got $homerCount times in $names');

  // ignore: avoid_print
  print('PASS');
}

void _assert(bool condition, String message) {
  if (!condition) {
    // ignore: avoid_print
    print('FAIL: $message');
    throw Exception(message);
  }
}
