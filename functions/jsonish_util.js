/**
 * Jsonish Utilities — copied from nerdster14/functions/jsonish_util.js
 *
 * ⚠️  MUST STAY IN SYNC WITH nerdster14/functions/jsonish_util.js
 * and with oneofus_common/lib/jsonish.dart → Jsonish.keysInOrder
 */

const crypto = require('crypto');

const key2order = {
  "statement": 0,
  "time": 1,
  "I": 2,
  "trust": 3,
  "block": 4,
  "replace": 5,
  "delegate": 6,
  "clear": 7,
  "rate": 8,
  "relate": 9,
  "dontRelate": 10,
  "equate": 11,
  "dontEquate": 12,
  "follow": 13,
  "set": 14, // hablotengo: set entry or field
  "with": 15,
  "other": 16,
  "moniker": 17,
  "revokeAt": 18,
  "domain": 19,
  "tags": 20,
  "recommend": 21,
  "dismiss": 22,
  "censor": 23,
  "stars": 24,
  "endpoint": 25,
  "comment": 26,
  "contentType": 27,
  "previous": 28,
  "signature": 29
};

function computeSHA1(str) {
  return crypto.createHash('sha1').update(str).digest('hex');
}

function compareKeys(key1, key2) {
  const i1 = key2order[key1];
  const i2 = key2order[key2];
  if (i1 != null && i2 != null) return i1 - i2;
  if (i1 == null && i2 == null) return key1 < key2 ? -1 : 1;
  return i1 != null ? -1 : 1;
}

function order(thing) {
  if (thing === null || typeof thing !== 'object') return thing;
  if (Array.isArray(thing)) return thing.map(order);
  const signature = thing.signature;
  const keys = Object.keys(thing).filter(k => k !== 'signature').sort(compareKeys);
  const out = {};
  for (const key of keys) out[key] = order(thing[key]);
  if (signature) out.signature = signature;
  return out;
}

async function getToken(input) {
  if (typeof input === 'string') return input;
  const ordered = order(input);
  return computeSHA1(JSON.stringify(ordered, null, 2));
}

function parseIrevoke(i) {
  if (!i) return {};
  if (typeof i === 'object') return i;
  if (!i.startsWith('{')) {
    return { [i]: null };
  } else {
    return JSON.parse(i);
  }
}

module.exports = { key2order, computeSHA1, compareKeys, order, getToken, parseIrevoke };
