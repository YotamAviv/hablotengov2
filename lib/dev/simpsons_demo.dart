import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hablotengo/dev/demo_key.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:hablotengo/sign_in_state.dart';
import 'package:oneofus_common/keys.dart';

/// Populates the Simpsons trust network and signs in as Lisa.
Future<void> simpsonsDemo({
  required FirebaseFirestore oneofusDb,
  required FirebaseFirestore habloDb,
}) async {
  // Identity keys
  final lisa = await DemoIdentityKey.create('lisa');
  final homer = await DemoIdentityKey.create('homer');
  final marge = await DemoIdentityKey.create('marge');
  final bart = await DemoIdentityKey.create('bart');
  final milhouse = await DemoIdentityKey.create('milhouse');
  final maggie = await DemoIdentityKey.create('maggie');

  // Trust network
  await homer.trust(marge, oneofusDb, moniker: 'Wife');
  await homer.trust(bart, oneofusDb, moniker: 'Son');
  await homer.trust(lisa, oneofusDb, moniker: 'Lisa');
  await homer.trust(maggie, oneofusDb, moniker: 'Maggie');
  await marge.trust(homer, oneofusDb, moniker: 'Hubby');
  await marge.trust(bart, oneofusDb, moniker: 'Bart');
  await marge.trust(lisa, oneofusDb, moniker: 'Lisa');
  await marge.trust(maggie, oneofusDb, moniker: 'Maggie');
  await bart.trust(homer, oneofusDb, moniker: 'Homer');
  await bart.trust(lisa, oneofusDb, moniker: 'Sis');
  await bart.trust(milhouse, oneofusDb, moniker: 'Milhouse');
  await lisa.trust(homer, oneofusDb, moniker: 'Dad');
  await lisa.trust(marge, oneofusDb, moniker: 'Mom');
  await lisa.trust(bart, oneofusDb, moniker: 'Bart');
  await lisa.trust(maggie, oneofusDb, moniker: 'Maggie');
  await milhouse.trust(bart, oneofusDb, moniker: 'Bart');
  await milhouse.trust(lisa, oneofusDb, moniker: 'Lisa');

  // Hablotengo delegate keys
  final lisaD = await DemoDelegateKey.create('lisa-hablo');
  final homerD = await DemoDelegateKey.create('homer-hablo');
  final margeD = await DemoDelegateKey.create('marge-hablo');
  final bartD = await DemoDelegateKey.create('bart-hablo');
  final milhouseD = await DemoDelegateKey.create('milhouse-hablo');
  final maggieD = await DemoDelegateKey.create('maggie-hablo');

  // Delegate statements (in oneofus emulator)
  await lisa.delegateTo(lisaD, oneofusDb);
  await homer.delegateTo(homerD, oneofusDb);
  await marge.delegateTo(margeD, oneofusDb);
  await bart.delegateTo(bartD, oneofusDb);
  await milhouse.delegateTo(milhouseD, oneofusDb);
  await maggie.delegateTo(maggieD, oneofusDb);

  // Contact cards (in hablotengo emulator)
  await lisaD.submitCard(habloDb, oneofusDb,
      name: 'Lisa Simpson',
      email: 'lisa@springfield.edu',
      contactPrefs: {
        'signal': [{'handle': '+15555550101', 'preferred': true}],
        'instagram': [{'handle': 'lisasimpson', 'preferred': false}],
      },
      visibility: VisibilityLevel.standard);

  await homerD.submitCard(habloDb, oneofusDb,
      name: 'Homer Simpson',
      email: 'homer@springfield-nuclear.com',
      phone: '+15555550102',
      contactPrefs: {
        'whatsapp': [{'handle': '+15555550102', 'preferred': true}],
      },
      visibility: VisibilityLevel.permissive);

  await margeD.submitCard(habloDb, oneofusDb,
      name: 'Marge Simpson',
      email: 'marge@springfield.net',
      contactPrefs: {
        'telegram': [{'handle': 'margesimpson', 'preferred': true}],
        'instagram': [{'handle': 'margesimpson', 'preferred': false}],
      },
      visibility: VisibilityLevel.standard);

  await bartD.submitCard(habloDb, oneofusDb,
      name: 'Bart Simpson',
      contactPrefs: {
        'instagram': [{'handle': 'bartmaniac', 'preferred': true}],
        'twitter_x': [{'handle': 'bartman', 'preferred': false}],
      },
      visibility: VisibilityLevel.permissive);

  await milhouseD.submitCard(habloDb, oneofusDb,
      name: 'Milhouse Van Houten',
      email: 'milhouse@springfield.edu',
      contactPrefs: {
        'signal': [{'handle': '+15555550105', 'preferred': true}],
      },
      visibility: VisibilityLevel.strict);

  // Maggie has no card yet — shows entry with no details

  // Sign in as Lisa
  final lisaJson = await lisa.publicKey.json;
  final fedKey = FedKey(lisaJson, kNativeEndpoint);
  await signInState.signInWithFedKey(fedKey, lisaD.keyPair);
}
