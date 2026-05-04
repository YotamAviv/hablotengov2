/**
 * Integration tests for getBatchContacts.
 * Requires the Hablo Firebase emulator running on port 5003
 * with Simpsons demo data seeded (createSimpsonsContactData.sh).
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');
const { keyToken } = require('../verify_util');
const SIMPSONS_KEYS = require('../simpsons_keys.json');

const BASE_URL = 'http://127.0.0.1:5003/hablotengo/us-central1';

async function batchContacts(requesterJwk, targetTokens) {
  const res = await fetch(`${BASE_URL}/getBatchContacts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: requesterJwk, demo: true, targetTokens }),
  });
  const body = await res.text();
  assert.strictEqual(res.status, 200, `getBatchContacts failed: ${body}`);
  return JSON.parse(body);
}

const lisaJwk = SIMPSONS_KEYS['lisa'];
const homerJwk = SIMPSONS_KEYS['homer'];
const margeJwk = SIMPSONS_KEYS['marge'];

const lisaToken           = keyToken(lisaJwk);
const homerToken          = keyToken(homerJwk);
const margeToken          = keyToken(margeJwk);
const sideshowJwk         = SIMPSONS_KEYS['sideshow'];
// Homer replaced his old key; the canonical token is homer2.
const homerCanonicalToken = keyToken(SIMPSONS_KEYS['homer2']);

const sideshowToken = keyToken(SIMPSONS_KEYS['sideshow']);

describe('getBatchContacts — trust filtering', () => {
  test('Lisa reads Homer and Marge — both found with correct names', async () => {
    const result = await batchContacts(lisaJwk, [homerCanonicalToken, margeToken]);
    assert.strictEqual(result[homerCanonicalToken]?.status, 'found',
      `Homer expected found, got: ${JSON.stringify(result[homerCanonicalToken])}`);
    assert.strictEqual(result[homerCanonicalToken]?.contact?.name, 'Homer Simpson',
      `Homer name wrong: ${result[homerCanonicalToken]?.contact?.name}`);
    assert.strictEqual(result[margeToken]?.status, 'found',
      `Marge expected found, got: ${JSON.stringify(result[margeToken])}`);
    assert.strictEqual(result[margeToken]?.contact?.name, 'Marge Simpson',
      `Marge name wrong: ${result[margeToken]?.contact?.name}`);
  });

  test('Sideshow (blocked by Marge) cannot read Lisa\'s contact', async () => {
    const result = await batchContacts(sideshowJwk, [lisaToken]);
    assert.strictEqual(result[lisaToken]?.status, 'denied',
      `Sideshow expected denied for Lisa, got: ${JSON.stringify(result[lisaToken])}`);
  });

  test('Mixed batch — Sideshow reads Krusty (found) and Lisa (denied)', async () => {
    const krustyToken = keyToken(SIMPSONS_KEYS['krusty']);
    const result = await batchContacts(sideshowJwk, [krustyToken, lisaToken]);
    assert.strictEqual(result[krustyToken]?.status, 'found');
    assert.strictEqual(result[lisaToken]?.status, 'denied');
  });
});

describe('getBatchContacts — self-reference', () => {
  test('Lisa includes her own token — status found, full contact returned', async () => {
    const result = await batchContacts(lisaJwk, [lisaToken]);
    assert.strictEqual(result[lisaToken]?.status, 'found',
      `Lisa self expected found, got: ${JSON.stringify(result[lisaToken])}`);
    assert.strictEqual(result[lisaToken]?.contact?.name, 'Lisa Simpson');
    // Self-reference bypasses filtering — no someHidden, no defaultStrictness field
    assert.ok(!result[lisaToken]?.someHidden, 'Self should not have someHidden');
  });
});

describe('getBatchContacts — entries visible at distance 1', () => {
  test('Homer at distance 1 from Lisa — all entries visible, no someHidden', async () => {
    const result = await batchContacts(lisaJwk, [homerCanonicalToken]);
    const homer = result[homerCanonicalToken];
    assert.strictEqual(homer?.status, 'found');
    const phone = homer?.contact?.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, `Expected phone entry for Homer at d=1`);
    const email = homer?.contact?.entries?.find(e => e.tech === 'email');
    assert.ok(email, `Expected email entry for Homer at d=1`);
    assert.ok(!homer?.someHidden, 'No entries should be hidden at distance 1');
  });

  test('Homer contact notes present', async () => {
    const result = await batchContacts(lisaJwk, [homerCanonicalToken]);
    assert.strictEqual(result[homerCanonicalToken]?.contact?.notes, 'Never call me');
  });
});
