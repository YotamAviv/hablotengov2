import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/ui/json_display.dart';

import 'app.dart';
import 'constants.dart';
import 'sign_in_state.dart';
import 'firebase_options.dart'; // gitignored; regenerate with: flutterfire configure
import 'key_store.dart';

void _signOutIfSessionExpiringSoon() {
  final sessionTime = signInState.sessionTime;
  if (sessionTime == null) return;
  final created = DateTime.tryParse(sessionTime);
  if (created == null) return;
  final age = DateTime.now().difference(created);
  if (age.inDays >= 5) {
    debugPrint('main: session age=${age.inDays}d, signing out');
    signInState.signOut();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TrustStatement.init();

  final String? fireParam = kIsWeb ? Uri.base.queryParameters['fire'] : null;
  final bool emulator = kIsWeb && Uri.base.host == 'localhost' && fireParam != 'prod';
  final bool demoMode = kIsWeb && Uri.base.queryParameters['demo'] == 'true';
  final String? startupTarget = kIsWeb ? Uri.base.queryParameters['target'] : null;
  debugPrint('main: Uri.base=${Uri.base} emulator=$emulator demoMode=$demoMode startupTarget=$startupTarget');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  if (emulator) {
    firestore.useFirestoreEmulator('localhost', kHabloFirestoreEmulatorPort);
  }

  JsonDisplay.highlightKeys = const {'I', 'verifiedIdentity'};

  final fireChoice = emulator ? FireChoice.emulator : FireChoice.prod;
  channelFactory = ChannelFactory(fireChoice);

  // OneOfUS domain: public trust-graph reads (no auth needed).
  channelFactory.register(
    kOneofusDomain,
    exportUrl: oneofusExportUrl(false),
    functionsUrl: oneofusWriteUrl(false),
    emulatorExportUrl: oneofusExportUrl(true),
    emulatorFunctionsUrl: oneofusWriteUrl(true),
  );

  // Hablo domain: session-authenticated writes (contact card saves).
  // exportUrl points to exportContact; response format update for CachedSource
  // head-bootstrap is deferred to work item 6.
  channelFactory.register(
    kHabloDomain,
    exportUrl: habloExportContactUrl(false),
    functionsUrl: habloFunctionsBaseUrl(false),
    emulatorExportUrl: habloExportContactUrl(true),
    emulatorFunctionsUrl: habloFunctionsBaseUrl(true),
    writeAuthHook: () => signInState.authPayload()!,
    readAuthHook: () => signInState.authPayload()!,
  );

  startKeyStorageCoordinator();
  await tryRestoreKeys();
  if (!demoMode && signInState.isDemo) signInState.signOut();
  _signOutIfSessionExpiringSoon();

  runApp(HabloApp(firestore: firestore, emulator: emulator, demoMode: demoMode, startupTarget: startupTarget));
}
