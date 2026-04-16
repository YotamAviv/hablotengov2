import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hablotengo/dev/demo_key.dart';
import 'package:hablotengo/logic/contact_repo.dart';
import 'package:hablotengo/models/contact_statement.dart';
import 'package:hablotengo/models/privacy_statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/keys.dart';

// ---------------------------------------------------------------------------
// TestResult & TestCase
// ---------------------------------------------------------------------------

enum TestStatus { pending, pass, fail }

class TestResult {
  final String name;
  TestStatus status;
  String? error;
  TestResult(this.name) : status = TestStatus.pending;
}

typedef TestFn = Future<void> Function();

Future<TestResult> _run(String name, TestFn fn) async {
  final r = TestResult(name);
  try {
    await fn();
    r.status = TestStatus.pass;
  } catch (e) {
    r.status = TestStatus.fail;
    r.error = e.toString();
  }
  return r;
}

void _assert(bool condition, String message) {
  if (!condition) throw AssertionError(message);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

Future<List<TestResult>> runAllTests() async {
  final results = <TestResult>[];

  // ---- Shared in-memory Firestores ----
  final oneofusDb = FakeFirebaseFirestore();
  final habloDb = FakeFirebaseFirestore();

  // ---- Simpsons network setup ----
  late DemoIdentityKey lisa, homer, marge, bart, milhouse;
  late DemoDelegateKey lisaD, homerD, margeD, bartD, milhouseD;

  results.add(await _run('Simpsons: create keys and trust graph', () async {
    lisa = await DemoIdentityKey.create('lisa');
    homer = await DemoIdentityKey.create('homer');
    marge = await DemoIdentityKey.create('marge');
    bart = await DemoIdentityKey.create('bart');
    milhouse = await DemoIdentityKey.create('milhouse');

    await homer.trust(marge, oneofusDb, moniker: 'Wife');
    await homer.trust(bart, oneofusDb, moniker: 'Son');
    await homer.trust(lisa, oneofusDb, moniker: 'Lisa');
    await marge.trust(homer, oneofusDb, moniker: 'Hubby');
    await marge.trust(bart, oneofusDb, moniker: 'Bart');
    await marge.trust(lisa, oneofusDb, moniker: 'Lisa');
    await bart.trust(homer, oneofusDb, moniker: 'Homer');
    await bart.trust(lisa, oneofusDb, moniker: 'Sis');
    await bart.trust(milhouse, oneofusDb, moniker: 'Milhouse');
    await lisa.trust(homer, oneofusDb, moniker: 'Dad');
    await lisa.trust(marge, oneofusDb, moniker: 'Mom');
    await lisa.trust(bart, oneofusDb, moniker: 'Bart');
    await milhouse.trust(bart, oneofusDb, moniker: 'Bart');
    await milhouse.trust(lisa, oneofusDb, moniker: 'Lisa');
  }));

  results.add(await _run('Simpsons: create delegate keys', () async {
    lisaD = await DemoDelegateKey.create('lisa-hablo');
    homerD = await DemoDelegateKey.create('homer-hablo');
    margeD = await DemoDelegateKey.create('marge-hablo');
    bartD = await DemoDelegateKey.create('bart-hablo');
    milhouseD = await DemoDelegateKey.create('milhouse-hablo');

    await lisa.delegateTo(lisaD, oneofusDb);
    await homer.delegateTo(homerD, oneofusDb);
    await marge.delegateTo(margeD, oneofusDb);
    await bart.delegateTo(bartD, oneofusDb);
    await milhouse.delegateTo(milhouseD, oneofusDb);
  }));

  results.add(await _run('Simpsons: write contact cards', () async {
    await lisaD.submitCard(habloDb, oneofusDb,
        name: 'Lisa Simpson',
        email: 'lisa@springfield.edu',
        contactPrefs: {
          'signal': [{'handle': '+15555550101', 'preferred': true}],
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
        visibility: VisibilityLevel.standard);

    await bartD.submitCard(habloDb, oneofusDb,
        name: 'Bart Simpson',
        contactPrefs: {
          'instagram': [{'handle': 'bartmaniac', 'preferred': true}],
        },
        visibility: VisibilityLevel.permissive);

    await milhouseD.submitCard(habloDb, oneofusDb,
        name: 'Milhouse Van Houten',
        email: 'milhouse@springfield.edu',
        visibility: VisibilityLevel.strict);
  }));

  results.add(await _run("Trust graph from Lisa's PoV includes Homer, Marge, Bart", () async {
    final repo = ContactRepo(oneofusFirestore: oneofusDb, habloFirestore: habloDb);
    final result = await repo.loadContacts(IdentityKey(lisa.token));
    final names = result.contacts.map((e) => e.contact?.name).whereType<String>().toSet();
    _assert(names.contains('Homer Simpson'), 'Homer not in Lisa contact list');
    _assert(names.contains('Marge Simpson'), 'Marge not in Lisa contact list');
    _assert(names.contains('Bart Simpson'), 'Bart not in Lisa contact list');
  }));

  results.add(await _run('Contact card round-trip: write then read back', () async {
    final repo = ContactRepo(oneofusFirestore: oneofusDb, habloFirestore: habloDb);
    final myCard = await repo.loadMyCard([DelegateKey(lisaD.token)]);
    _assert(myCard.contact != null, 'Lisa card not found after write');
    _assert(myCard.contact!.name == 'Lisa Simpson', 'Name mismatch: ${myCard.contact!.name}');
    _assert(myCard.contact!.emails.any((e) => e['address'] == 'lisa@springfield.edu'),
        'Email not found in card');
  }));

  results.add(await _run('Privacy statement defaults to standard', () async {
    final repo = ContactRepo(oneofusFirestore: oneofusDb, habloFirestore: habloDb);
    final myCard = await repo.loadMyCard(
      [DelegateKey(lisaD.token)],
    );
    _assert(myCard.privacy != null, 'Lisa privacy statement not found');
    _assert(myCard.privacy!.visibilityLevel == VisibilityLevel.standard,
        'Expected standard, got ${myCard.privacy!.visibilityLevel}');
  }));

  results.add(await _run('Milhouse in trust graph via Bart (distance 2)', () async {
    final repo = ContactRepo(oneofusFirestore: oneofusDb, habloFirestore: habloDb);
    final result = await repo.loadContacts(IdentityKey(lisa.token));
    final milhouseEntry = result.contacts
        .where((e) => e.contact?.name == 'Milhouse Van Houten')
        .firstOrNull;
    _assert(milhouseEntry != null, 'Milhouse not found in contacts');
    _assert((milhouseEntry!.distance) <= 3, 'Milhouse too far: ${milhouseEntry.distance}');
  }));

  results.add(await _run('Contact card update: newer timestamp wins', () async {
    final repo = ContactRepo(oneofusFirestore: oneofusDb, habloFirestore: habloDb);

    // Write an updated card for Lisa
    await lisaD.submitCard(habloDb, oneofusDb,
        name: 'Lisa Simpson (updated)',
        email: 'lisa2@springfield.edu',
        visibility: VisibilityLevel.standard);

    final myCard = await repo.loadMyCard([DelegateKey(lisaD.token)]);
    _assert(myCard.contact!.name == 'Lisa Simpson (updated)',
        'Expected updated name, got ${myCard.contact!.name}');
    _assert(myCard.contact!.emails.any((e) => e['address'] == 'lisa2@springfield.edu'),
        'Updated email not found');
  }));

  return results;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TestRunnerScreen extends StatefulWidget {
  const TestRunnerScreen({super.key});

  @override
  State<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends State<TestRunnerScreen> {
  List<TestResult> _results = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _running = true; _results = []; });
    // Init statement factories before tests
    TrustStatement.init();
    ContactStatement.init();
    PrivacyStatement.init();
    final results = await runAllTests();
    setState(() { _running = false; _results = results; });
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r.status == TestStatus.pass).length;
    final failed = _results.where((r) => r.status == TestStatus.fail).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Tests'),
        actions: [
          if (!_running)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _run, tooltip: 'Re-run'),
        ],
      ),
      body: Column(
        children: [
          if (_running) const LinearProgressIndicator(),
          if (!_running && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '$passed passed, $failed failed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: failed > 0 ? Colors.red : Colors.green,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                final icon = r.status == TestStatus.pass
                    ? Icons.check_circle
                    : r.status == TestStatus.fail
                        ? Icons.error
                        : Icons.pending;
                final color = r.status == TestStatus.pass
                    ? Colors.green
                    : r.status == TestStatus.fail
                        ? Colors.red
                        : Colors.grey;
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(r.name),
                  subtitle: r.error != null ? Text(r.error!, style: const TextStyle(fontSize: 11)) : null,
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
