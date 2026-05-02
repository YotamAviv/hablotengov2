/**
 * Integration tests for equivalent-key endpoints.
 * Requires both emulators running:
 *   hablotengo:  ./bin/start_emulator.sh        (Firestore 8082, Functions 5003)
 *   one-of-us:   oneofusv22/bin/start_emulator.sh (Functions 5002)
 *
 * Resets Firestore to the known Simpsons state before each suite by running
 * ./bin/createSimpsonsContactData.sh.
 *
 * Test conventions (applies to all test files):
 *   - Tests MAY rely on demo data being present (seeded by createSimpsonsContactData.sh).
 *   - Tests MAY create new data and then modify that same data.
 *   - Tests MUST NOT modify existing demo data without restoring it (reset() handles this).
 *   - Test files MUST run serially (--concurrency=1 in package.json) because reset()
 *     clears all Firestore data; concurrent runs would corrupt other tests.
 */

const { describe, test, before } = require('node:test');
const assert = require('node:assert');
const { execSync } = require('child_process');
const path = require('path');

const REPO_DIR = path.join(__dirname, '..', '..');
const BASE_URL = 'http://127.0.0.1:5003/hablotengo/us-central1';

const SIMPSONS_KEYS = require('../simpsons_keys.json');
const homer2Jwk = SIMPSONS_KEYS['homer2'];
const homerJwk  = SIMPSONS_KEYS['homer'];   // old key

// Tokens are sha1 fingerprints of the public keys — taken from known trust graph.
const { keyToken } = require('../verify_util');
const HOMER2_TOKEN = keyToken(homer2Jwk);
const HOMER_TOKEN  = keyToken(homerJwk);

async function post(endpoint, body) {
  const res = await fetch(`${BASE_URL}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return res;
}

function demoAuth(jwk) {
  return { identity: jwk, demo: true };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForEmulator(maxWaitMs = 60000) {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${BASE_URL}/getEquivalentStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identity: homer2Jwk, demo: true, tokens: [] }),
      });
      const text = await res.text();
      if (res.status < 500 && !text.includes('does not exist')) return;
    } catch (_) {}
    await sleep(500);
  }
  throw new Error('Emulator did not become ready in time');
}

async function reset() {
  execSync('./bin/reset_emulator.sh', { cwd: REPO_DIR, stdio: 'pipe' });
  await waitForEmulator();
}

// ---------------------------------------------------------------------------
// dismissEquivalent
// ---------------------------------------------------------------------------

describe('dismissEquivalent — integration', { concurrency: false }, () => {
  before(reset);

  test('homer2 can dismiss homer (old key)', async () => {
    const res = await post('dismissEquivalent', {
      ...demoAuth(homer2Jwk),
      equivalentToken: HOMER_TOKEN,
    });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
  });

  test('dismissed token is still not disabled', async () => {
    const res = await post('getEquivalentStatus', {
      ...demoAuth(homer2Jwk),
      tokens: [HOMER_TOKEN],
    });
    const body = await res.json();
    assert.strictEqual(body[HOMER_TOKEN].disabledBy, null);
  });
});

// ---------------------------------------------------------------------------
// disableEquivalent (no merge)
// ---------------------------------------------------------------------------

describe('disableEquivalent without merge — integration', { concurrency: false }, () => {
  before(reset);

  test('homer2 can disable homer (old key)', async () => {
    const res = await post('disableEquivalent', {
      ...demoAuth(homer2Jwk),
      equivalentToken: HOMER_TOKEN,
      mergeContact: false,
    });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
  });

  test('getEquivalentStatus shows homer disabled by homer2', async () => {
    const res = await post('getEquivalentStatus', {
      ...demoAuth(homer2Jwk),
      tokens: [HOMER_TOKEN],
    });
    const body = await res.json();
    assert.strictEqual(body[HOMER_TOKEN].disabledBy, HOMER2_TOKEN);
  });

  test('disabling again returns 409', async () => {
    const res = await post('disableEquivalent', {
      ...demoAuth(homer2Jwk),
      equivalentToken: HOMER_TOKEN,
      mergeContact: false,
    });
    assert.strictEqual(res.status, 409);
  });
});

// ---------------------------------------------------------------------------
// disableEquivalent (with merge)
// ---------------------------------------------------------------------------

describe('disableEquivalent with merge — integration', { concurrency: false }, () => {
  before(reset);

  test('homer2 merges and disables homer (old key)', async () => {
    const res = await post('disableEquivalent', {
      ...demoAuth(homer2Jwk),
      equivalentToken: HOMER_TOKEN,
      mergeContact: true,
    });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
  });

  test('homer2 card now includes homer\'s phone entry', async () => {
    const res = await post('getMyContact', { ...demoAuth(homer2Jwk) });
    const body = await res.json();
    const phone = body.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, `Expected a phone entry after merge; got entries: ${JSON.stringify(body.entries)}`);
    assert.strictEqual(phone.value, '+1-555-HOMER');
  });
});

// ---------------------------------------------------------------------------
// enableAccount
// ---------------------------------------------------------------------------

describe('enableAccount — integration', { concurrency: false }, () => {
  before(async () => {
    await reset();
    // Disable homer's (old key) account as setup, then homer re-enables it.
    const res = await post('disableEquivalent', {
      ...demoAuth(homer2Jwk),
      equivalentToken: HOMER_TOKEN,
      mergeContact: false,
    });
    assert.strictEqual(res.status, 200, `setup disableEquivalent failed: ${await res.text()}`);
  });

  test('homer can enable their own disabled account', async () => {
    const res = await post('enableAccount', { ...demoAuth(homerJwk) });
    const body = await res.text();
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${body}`);
  });

  test('getEquivalentStatus shows homer no longer disabled', async () => {
    const res = await post('getEquivalentStatus', {
      ...demoAuth(homer2Jwk),
      tokens: [HOMER_TOKEN],
    });
    const body = await res.json();
    assert.strictEqual(body[HOMER_TOKEN].disabledBy, null);
  });
});
