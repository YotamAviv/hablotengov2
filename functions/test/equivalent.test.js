const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert');

// ---------------------------------------------------------------------------
// Firestore mock
// ---------------------------------------------------------------------------

const _docs = {};

function _docRef(collection, id) {
  const key = `${collection}/${id}`;
  return {
    get: async () => {
      const data = _docs[key];
      return { exists: !!data, data: () => data };
    },
    set: async (val, opts) => {
      if (opts && opts.merge) {
        const current = _docs[key] || {};
        const next = { ...current };
        for (const [k, v] of Object.entries(val)) {
          if (v && v._type === 'arrayUnion') {
            const existing = Array.isArray(current[k]) ? current[k] : [];
            next[k] = [...new Set([...existing, ...v._elements])];
          } else {
            next[k] = v;
          }
        }
        _docs[key] = next;
      } else {
        _docs[key] = { ...val };
      }
    },
    update: async (val) => {
      const current = _docs[key] || {};
      const next = { ...current };
      for (const [k, v] of Object.entries(val)) {
        if (v && v._type === 'delete') {
          delete next[k];
        } else {
          next[k] = v;
        }
      }
      _docs[key] = next;
    },
  };
}

const _adminMock = {
  firestore: () => ({
    collection: (col) => ({ doc: (id) => _docRef(col, id) }),
  }),
};
_adminMock.firestore.FieldValue = {
  arrayUnion: (...elements) => ({ _type: 'arrayUnion', _elements: elements }),
  delete: () => ({ _type: 'delete' }),
};

// ---------------------------------------------------------------------------
// Configurable trust pipeline mock
// ---------------------------------------------------------------------------

// Set this before each disableEquivalent test to control what replacements the
// trust graph returns. Maps old token → canonical token.
let _mockReplacements = new Map();

// ---------------------------------------------------------------------------
// Patch require before loading the modules under test
// ---------------------------------------------------------------------------

const Module = require('module');
const _origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'firebase-admin') return _adminMock;
  if (request === 'firebase-admin/firestore') return { FieldValue: _adminMock.firestore.FieldValue };
  if (request.endsWith('auth_util')) {
    return {
      verifyAuth: (req) => {
        if (req._demoAuth) return { identityToken: 'canonical', isDemo: true };
        return { identityToken: 'canonical', isDemo: false };
      },
    };
  }
  if (request.endsWith('multi_target_trust_pipeline')) {
    return {
      MultiTargetTrustPipeline: class {
        async buildAll(tokens) {
          const graphs = new Map();
          for (const tok of tokens) {
            graphs.set(tok, { replacements: _mockReplacements });
          }
          return graphs;
        }
      },
    };
  }
  if (request.endsWith('oneofus_source') || request.endsWith('trust_algorithm')) return {};
  return _origLoad.apply(this, arguments);
};

const { handleGetEquivalentStatus } = require('../get_equivalent_status');
const { handleDismissEquivalent } = require('../dismiss_equivalent');
const { handleDisableEquivalent } = require('../disable_equivalent');
const { handleEnableAccount } = require('../enable_account');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeReq(body, { demo = false } = {}) {
  return { body, _demoAuth: demo };
}

function makeRes() {
  const res = {};
  res.status = (code) => { res._status = code; return res; };
  res.json = (data) => { res._body = data; };
  res.send = (data) => { res._body = data; };
  res.setHeader = () => {};
  return res;
}

// ---------------------------------------------------------------------------
// getEquivalentStatus
// ---------------------------------------------------------------------------

describe('getEquivalentStatus', () => {
  beforeEach(() => { Object.keys(_docs).forEach(k => delete _docs[k]); });

  test('returns disabledBy=null for unknown token', async () => {
    const res = makeRes();
    await handleGetEquivalentStatus(makeReq({ tokens: ['tok_a'] }), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(res._body['tok_a'].disabledBy, null);
  });

  test('returns disabledBy when set', async () => {
    _docs['settings/tok_old'] = { disabledBy: 'canonical' };
    const res = makeRes();
    await handleGetEquivalentStatus(makeReq({ tokens: ['tok_old'] }), res);
    assert.strictEqual(res._body['tok_old'].disabledBy, 'canonical');
  });

  test('returns 400 for missing tokens', async () => {
    const res = makeRes();
    await handleGetEquivalentStatus(makeReq({}), res);
    assert.strictEqual(res._status, 400);
  });
});

// ---------------------------------------------------------------------------
// dismissEquivalent
// ---------------------------------------------------------------------------

describe('dismissEquivalent', () => {
  beforeEach(() => { Object.keys(_docs).forEach(k => delete _docs[k]); });

  test('adds equivalentToken to dismissedEquivalents', async () => {
    const res = makeRes();
    await handleDismissEquivalent(makeReq({ equivalentToken: 'tok_old' }), res);
    assert.strictEqual(res._status, 200);
    assert.ok(_docs['settings/canonical'].dismissedEquivalents.includes('tok_old'));
  });

  test('demo user can dismiss', async () => {
    const res = makeRes();
    await handleDismissEquivalent(makeReq({ equivalentToken: 'tok_old' }, { demo: true }), res);
    assert.strictEqual(res._status, 200);
    assert.ok(_docs['settings/canonical'].dismissedEquivalents.includes('tok_old'));
  });

  test('accumulates multiple dismissed tokens', async () => {
    await handleDismissEquivalent(makeReq({ equivalentToken: 'tok_a' }), makeRes());
    await handleDismissEquivalent(makeReq({ equivalentToken: 'tok_b' }), makeRes());
    const settings = _docs['settings/canonical'];
    assert.ok(settings.dismissedEquivalents.includes('tok_a'));
    assert.ok(settings.dismissedEquivalents.includes('tok_b'));
  });

  test('returns 400 for missing equivalentToken', async () => {
    const res = makeRes();
    await handleDismissEquivalent(makeReq({}), res);
    assert.strictEqual(res._status, 400);
  });
});

// ---------------------------------------------------------------------------
// disableEquivalent
// ---------------------------------------------------------------------------

describe('disableEquivalent', () => {
  beforeEach(() => {
    Object.keys(_docs).forEach(k => delete _docs[k]);
    _mockReplacements = new Map([['tok_old', 'canonical']]);
  });

  test('disables a verified equivalent', async () => {
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: false }), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(_docs['settings/tok_old'].disabledBy, 'canonical');
  });

  test('demo user can disable', async () => {
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: false }, { demo: true }), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(_docs['settings/tok_old'].disabledBy, 'canonical');
  });

  test('rejects non-equivalent token', async () => {
    _mockReplacements = new Map(); // tok_old not replaced by canonical
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: false }), res);
    assert.strictEqual(res._status, 403);
  });

  test('rejects if already disabled', async () => {
    _docs['settings/tok_old'] = { disabledBy: 'someone' };
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: false }), res);
    assert.strictEqual(res._status, 409);
  });

  test('rejects disabling own canonical key', async () => {
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'canonical', mergeContact: false }), res);
    assert.strictEqual(res._status, 400);
  });

  test('merges non-duplicate entries from equivalent into canonical', async () => {
    _docs['contacts/canonical'] = { entries: [{ tech: 'email', value: 'a@b.com' }] };
    _docs['contacts/tok_old'] = { entries: [
      { tech: 'email', value: 'a@b.com' },   // duplicate — should not be added
      { tech: 'phone', value: '555-1234' },   // new — should be added
    ]};
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: true }), res);
    assert.strictEqual(res._status, 200);
    const entries = _docs['contacts/canonical'].entries;
    assert.strictEqual(entries.length, 2);
    assert.ok(entries.some(e => e.tech === 'phone' && e.value === '555-1234'));
    assert.strictEqual(entries.filter(e => e.tech === 'email').length, 1);
  });

  test('merge with no canonical card copies equivalent card', async () => {
    _docs['contacts/tok_old'] = { name: 'Homer', entries: [{ tech: 'phone', value: '555-0000' }] };
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ equivalentToken: 'tok_old', mergeContact: true }), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(_docs['contacts/canonical'].name, 'Homer');
  });

  test('returns 400 for missing equivalentToken', async () => {
    const res = makeRes();
    await handleDisableEquivalent(makeReq({ mergeContact: false }), res);
    assert.strictEqual(res._status, 400);
  });
});

// ---------------------------------------------------------------------------
// enableAccount
// ---------------------------------------------------------------------------

describe('enableAccount', () => {
  beforeEach(() => { Object.keys(_docs).forEach(k => delete _docs[k]); });

  test('removes disabledBy from settings', async () => {
    _docs['settings/canonical'] = { disabledBy: 'someone', showEmptyCards: true };
    const res = makeRes();
    await handleEnableAccount(makeReq({}), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(_docs['settings/canonical'].disabledBy, undefined);
    assert.strictEqual(_docs['settings/canonical'].showEmptyCards, true);
  });

  test('demo user can enable', async () => {
    _docs['settings/canonical'] = { disabledBy: 'someone' };
    const res = makeRes();
    await handleEnableAccount(makeReq({}, { demo: true }), res);
    assert.strictEqual(res._status, 200);
    assert.strictEqual(_docs['settings/canonical'].disabledBy, undefined);
  });
});
