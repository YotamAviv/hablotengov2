/**
 * Unit tests for DelegateResolver.
 * No Firebase emulator required — delegate-finding tests use in-memory data;
 * fetchStatements tests use a mock Firestore.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const { DelegateResolver } = require('../delegate_resolver');
const { fetchDelegateStatements } = require('../statement_fetcher');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeGraph(equivalent2canonical = new Map()) {
  return { equivalent2canonical };
}

/** Builds a minimal OOU delegate statement. */
function delegateStmt(delegateToken, domain, { time = '2024-01-01T00:00:00Z', revokeAt } = {}) {
  return {
    delegate: delegateToken, // already a token string for simplicity
    with: { domain, ...(revokeAt !== undefined ? { revokeAt } : {}) },
    time,
  };
}

/**
 * Mock Firestore for hablotengo stream layout:
 * streams/{delegateToken}_{identityToken}/statements
 *
 * streams: Map of `${delegateToken}_${identityToken}` → statements[] (unsorted)
 */
function makeMockDb(streams) {
  return {
    collection: (_col) => ({
      doc: (id) => ({
        collection: (_sub) => ({
          doc: (_docId) => ({ get: async () => ({ exists: false }) }),
          orderBy: (_field, _dir) => {
            const stmts = (streams.get(id) || [])
              .slice()
              .sort((a, b) => (a.time > b.time ? -1 : 1));
            return {
              limit: (n) => ({
                get: async () => ({
                  empty: stmts.length === 0,
                  docs: stmts.slice(0, n).map(s => ({ data: () => s })),
                }),
              }),
              get: async () => ({
                empty: stmts.length === 0,
                docs: stmts.map(s => ({ data: () => s })),
              }),
            };
          },
        }),
      }),
    }),
  };
}

const DOMAIN = 'hablotengo.com';

// ─── Delegate-finding tests (no I/O) ──────────────────────────────────────────

describe('DelegateResolver — delegate finding', () => {
  test('returns empty for identity with no delegate statements', () => {
    const oouCache = new Map([['I1', []]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    assert.deepStrictEqual(resolver.getDelegatesForIdentity('I1'), []);
  });

  test('finds a single delegate', () => {
    const oouCache = new Map([['I1', [delegateStmt('D1', DOMAIN)]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    assert.deepStrictEqual(resolver.getDelegatesForIdentity('I1'), ['D1']);
  });

  test('ignores delegates from other domains', () => {
    const oouCache = new Map([['I1', [
      delegateStmt('D_nerdster', 'nerdster.org'),
      delegateStmt('D_hablo', DOMAIN),
    ]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    assert.deepStrictEqual(resolver.getDelegatesForIdentity('I1'), ['D_hablo']);
  });

  test('includes predecessors via equivalence group', () => {
    // I2 replaced I1; I2 has D2, I1 had D1
    const equiv = new Map([['I1', 'I2']]);
    const oouCache = new Map([
      ['I2', [delegateStmt('D2', DOMAIN)]],
      ['I1', [delegateStmt('D1', DOMAIN)]],
    ]);
    const resolver = new DelegateResolver(makeGraph(equiv), oouCache);
    const delegates = resolver.getDelegatesForIdentity('I2');
    assert.ok(delegates.includes('D1'), 'should include predecessor delegate D1');
    assert.ok(delegates.includes('D2'), 'should include current delegate D2');
  });

  test('handles transitive predecessors (I1 → I2 → I3)', () => {
    const equiv = new Map([['I1', 'I2'], ['I2', 'I3']]);
    const oouCache = new Map([
      ['I3', [delegateStmt('D3', DOMAIN)]],
      ['I2', [delegateStmt('D2', DOMAIN)]],
      ['I1', [delegateStmt('D1', DOMAIN)]],
    ]);
    const resolver = new DelegateResolver(makeGraph(equiv), oouCache);
    const delegates = resolver.getDelegatesForIdentity('I3');
    assert.ok(delegates.includes('D1'), 'D1 from I1');
    assert.ok(delegates.includes('D2'), 'D2 from I2');
    assert.ok(delegates.includes('D3'), 'D3 from I3');
  });

  test('first identity to claim a delegate wins; second gets a notification', () => {
    const oouCache = new Map([
      ['I1', [delegateStmt('D_shared', DOMAIN, { time: '2024-01-02T00:00:00Z' })]],
      ['I2', [delegateStmt('D_shared', DOMAIN, { time: '2024-01-01T00:00:00Z' })]],
    ]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    resolver.getDelegatesForIdentity('I1'); // I1 claims D_shared first
    resolver.getDelegatesForIdentity('I2'); // I2 also claims D_shared

    assert.strictEqual(resolver.getIdentityForDelegate('D_shared'), 'I1');
    assert.strictEqual(resolver.notifications.length, 1);
    assert.ok(resolver.notifications[0].isConflict);
  });

  test('revokeAt kSinceAlways is recorded as a constraint', () => {
    const oouCache = new Map([['I1', [
      delegateStmt('D1', DOMAIN, { revokeAt: '<since always>' }),
    ]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    resolver.getDelegatesForIdentity('I1');
    assert.strictEqual(resolver.getConstraintForDelegate('D1'), '<since always>');
  });

  test('most recent delegate statement wins (time ordering)', () => {
    // D1 is first active, then revoked
    const oouCache = new Map([['I1', [
      delegateStmt('D1', DOMAIN, { time: '2024-01-02T00:00:00Z', revokeAt: '<since always>' }), // newer — revoked
      delegateStmt('D1', DOMAIN, { time: '2024-01-01T00:00:00Z' }), // older — active
    ]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    resolver.getDelegatesForIdentity('I1');
    // most recent is the revocation; that should win
    assert.strictEqual(resolver.getConstraintForDelegate('D1'), '<since always>');
  });

  test('resolveAll finds delegates across all canonical identities', () => {
    const oouCache = new Map([
      ['I1', [delegateStmt('D1', DOMAIN)]],
      ['I2', [delegateStmt('D2', DOMAIN)]],
    ]);
    const resolver = new DelegateResolver(makeGraph(), oouCache);
    resolver.resolveAll();
    const all = resolver.getAllDelegateTokens();
    assert.ok(all.has('D1'));
    assert.ok(all.has('D2'));
  });

  test('resolveAll skips non-canonical (equivalent) keys', () => {
    const equiv = new Map([['I1_old', 'I1']]);
    const oouCache = new Map([
      ['I1', [delegateStmt('D1', DOMAIN)]],
      ['I1_old', [delegateStmt('D_old', DOMAIN)]],
    ]);
    const resolver = new DelegateResolver(makeGraph(equiv), oouCache);
    resolver.resolveAll();
    // I1_old is non-canonical so resolveAll skips it as a top-level identity.
    // But getDelegatesForIdentity('I1') should include D_old via the equivalence group.
    const delegates = resolver.getDelegatesForIdentity('I1');
    assert.ok(delegates.includes('D1'));
    assert.ok(delegates.includes('D_old'));
  });
});

// ─── fetchStatements tests (mock Firestore) ────────────────────────────────────

describe('fetchDelegateStatements', () => {
  test('returns empty array when identity has no delegates', async () => {
    const oouCache = new Map([['I1', []]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache, { maxStatements: 1 });
    const db = makeMockDb(new Map());
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.deepStrictEqual(results, []);
  });

  test('fetches the latest statement from a single stream (maxStatements=1)', async () => {
    const oouCache = new Map([['I1', [delegateStmt('D1', DOMAIN)]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache, { maxStatements: 1 });
    const contactStmt = { time: '2024-06-01T00:00:00Z', content: 'hello' };
    const db = makeMockDb(new Map([['D1_I1', [contactStmt]]]));
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.strictEqual(results.length, 1);
    assert.deepStrictEqual(results[0], contactStmt);
  });

  test('returns latest across two streams when identity has two delegates', async () => {
    const oouCache = new Map([['I1', [
      delegateStmt('D1', DOMAIN, { time: '2024-01-01T00:00:00Z' }),
      delegateStmt('D2', DOMAIN, { time: '2024-01-02T00:00:00Z' }),
    ]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache, { maxStatements: 1 });
    const older = { time: '2024-05-01T00:00:00Z', content: 'old' };
    const newer = { time: '2024-06-01T00:00:00Z', content: 'new' };
    const db = makeMockDb(new Map([
      ['D1_I1', [older]],
      ['D2_I1', [newer]],
    ]));
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.strictEqual(results[0].content, 'new');
  });

  test('skips stream for revoked (kSinceAlways) delegate', async () => {
    const oouCache = new Map([['I1', [
      delegateStmt('D1', DOMAIN, { revokeAt: '<since always>' }),
    ]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache, { maxStatements: 1 });
    const db = makeMockDb(new Map([['D1_I1', [{ time: '2024-06-01T00:00:00Z' }]]]));
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.deepStrictEqual(results, []);
  });

  test('fetches from predecessor stream when identity was replaced', async () => {
    const equiv = new Map([['I1_old', 'I1']]);
    const oouCache = new Map([
      ['I1',     [delegateStmt('D_new', DOMAIN)]],
      ['I1_old', [delegateStmt('D_old', DOMAIN)]],
    ]);
    const resolver = new DelegateResolver(makeGraph(equiv), oouCache, { maxStatements: 1 });
    const oldStmt  = { time: '2023-01-01T00:00:00Z', content: 'old contact' };
    const newStmt  = { time: '2024-06-01T00:00:00Z', content: 'new contact' };
    const db = makeMockDb(new Map([
      ['D_old_I1_old', [oldStmt]],
      ['D_new_I1',     [newStmt]],
    ]));
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.strictEqual(results[0].content, 'new contact');
    assert.strictEqual(results.length >= 1, true);
  });

  test('maxStatements=Infinity returns all statements from stream', async () => {
    const oouCache = new Map([['I1', [delegateStmt('D1', DOMAIN)]]]);
    const resolver = new DelegateResolver(makeGraph(), oouCache, { maxStatements: Infinity });
    const stmts = [
      { time: '2024-03-01T00:00:00Z', n: 3 },
      { time: '2024-02-01T00:00:00Z', n: 2 },
      { time: '2024-01-01T00:00:00Z', n: 1 },
    ];
    const db = makeMockDb(new Map([['D1_I1', stmts]]));
    const results = await fetchDelegateStatements(resolver,'I1', {}, db);
    assert.strictEqual(results.length, 3);
    assert.strictEqual(results[0].n, 3); // most recent first
  });
});
