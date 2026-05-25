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

async function getContacts(requesterJwk) {
  const res = await fetch(`${BASE_URL}/getBatchContacts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: requesterJwk, demo: true }),
  });
  const body = await res.text();
  assert.strictEqual(res.status, 200, `getBatchContacts failed: ${body}`);
  const parsed = JSON.parse(body);
  assert.ok(parsed.selfToken, 'Response must have selfToken');
  assert.ok(Array.isArray(parsed.contacts), 'Response must have contacts array');
  return parsed;
}

function findContact(contacts, token) {
  return contacts.find(c => c.token === token);
}

const lisaJwk  = SIMPSONS_KEYS['lisa'];
const margeJwk = SIMPSONS_KEYS['marge'];
const sideshowJwk = SIMPSONS_KEYS['sideshow'];

const lisaToken  = keyToken(lisaJwk);
const margeToken = keyToken(margeJwk);
const homerCanonicalToken = keyToken(SIMPSONS_KEYS['homer2']);
const sideshowToken = keyToken(SIMPSONS_KEYS['sideshow']);

describe('getBatchContacts — response shape', () => {
  test('response has selfToken matching requester identity', async () => {
    const result = await getContacts(lisaJwk);
    assert.strictEqual(result.selfToken, lisaToken, 'selfToken should match Lisa');
  });

  test('contacts array includes self entry', async () => {
    const result = await getContacts(lisaJwk);
    const self = findContact(result.contacts, lisaToken);
    assert.ok(self, 'Self entry must be present in contacts');
    assert.strictEqual(self.status, 'found');
    assert.strictEqual(self.contact?.name, 'Lisa Simpson');
  });

  test('each contact has token, monikers, keyPayload, status', async () => {
    const result = await getContacts(lisaJwk);
    for (const c of result.contacts) {
      assert.ok(typeof c.token === 'string', `token must be a string: ${c.token}`);
      assert.ok(Array.isArray(c.monikers), `monikers must be array for ${c.token}`);
      assert.ok(c.status, `status must be present for ${c.token}`);
      // keyPayload may be null for tokens whose pubKey couldn't be derived
      if (c.keyPayload !== null) {
        assert.ok(c.keyPayload?.key, `keyPayload.key must exist for ${c.token}`);
      }
    }
  });
});

describe('getBatchContacts — trust filtering', () => {
  test('Lisa finds Homer with correct name', async () => {
    const result = await getContacts(lisaJwk);
    const homer = findContact(result.contacts, homerCanonicalToken);
    assert.strictEqual(homer?.status, 'found',
      `Homer expected found, got: ${JSON.stringify(homer)}`);
    assert.strictEqual(homer?.contact?.name, 'Homer Simpson');
  });

  test('Marge appears in contact list (federated — contact data may be not_found)', async () => {
    const result = await getContacts(lisaJwk);
    const marge = findContact(result.contacts, margeToken);
    assert.ok(marge, 'Marge should appear in contacts');
    assert.ok(['found', 'not_found'].includes(marge.status),
      `Marge status should be found or not_found, got: ${marge.status}`);
  });

  test('Sideshow (blocked by Marge) cannot read Lisa — status denied', async () => {
    const result = await getContacts(sideshowJwk);
    const lisa = findContact(result.contacts, lisaToken);
    assert.strictEqual(lisa?.status, 'denied',
      `Sideshow expected denied for Lisa, got: ${JSON.stringify(lisa)}`);
  });

  test('Sideshow finds Krusty (found) and Lisa (denied) in same response', async () => {
    const krustyToken = keyToken(SIMPSONS_KEYS['krusty']);
    const result = await getContacts(sideshowJwk);
    const krusty = findContact(result.contacts, krustyToken);
    const lisa = findContact(result.contacts, lisaToken);
    assert.strictEqual(krusty?.status, 'found');
    assert.strictEqual(lisa?.status, 'denied');
  });
});

describe('getBatchContacts — self entry', () => {
  test('self entry: no someHidden, rawStatement present', async () => {
    const result = await getContacts(lisaJwk);
    const self = findContact(result.contacts, lisaToken);
    assert.ok(!self?.someHidden, 'Self should not have someHidden');
    assert.ok(self?.rawStatement, 'Self should have rawStatement');
  });
});

describe('getBatchContacts — monikers', () => {
  test('Homer has monikers from trust statements', async () => {
    const result = await getContacts(lisaJwk);
    const homer = findContact(result.contacts, homerCanonicalToken);
    assert.ok(Array.isArray(homer?.monikers) && homer.monikers.length > 0,
      `Homer should have at least one moniker, got: ${JSON.stringify(homer?.monikers)}`);
  });

  test('Lisa self entry has label from trust statements', async () => {
    const result = await getContacts(lisaJwk);
    const self = findContact(result.contacts, lisaToken);
    // Label may be null for self if no one in the graph has trusted Lisa with a moniker yet.
    // Just verify the field exists.
    assert.ok('label' in self, 'Self entry must have label field');
  });
});

describe('getBatchContacts — entries visible at distance 1', () => {
  test('Homer at distance 1 from Lisa — all entries visible, no someHidden', async () => {
    const result = await getContacts(lisaJwk);
    const homer = findContact(result.contacts, homerCanonicalToken);
    assert.strictEqual(homer?.status, 'found');
    const phone = homer?.contact?.entries?.find(e => e.tech === 'phone');
    assert.ok(phone, 'Expected phone entry for Homer at d=1');
    const email = homer?.contact?.entries?.find(e => e.tech === 'email');
    assert.ok(email, 'Expected email entry for Homer at d=1');
    assert.ok(!homer?.someHidden, 'No entries should be hidden at distance 1');
  });

  test('Homer contact notes present', async () => {
    const result = await getContacts(lisaJwk);
    const homer = findContact(result.contacts, homerCanonicalToken);
    assert.strictEqual(homer?.contact?.notes, 'Never call me');
  });
});
