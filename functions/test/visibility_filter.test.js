const { test, describe } = require('node:test');
const assert = require('node:assert');

const {
  permissivePathRequirement,
  defaultPathRequirement,
  strictPathRequirement,
  reduceTrustGraph,
} = require('../trust_algorithm');

const { _meetsStrictness, _filterEntries } = require('../get_batch_contacts');

// ---------------------------------------------------------------------------
// Strictness functions
// ---------------------------------------------------------------------------

describe('permissivePathRequirement', () => {
  test('always returns 1 regardless of distance', () => {
    for (const d of [1, 2, 3, 4, 5, 10]) {
      assert.strictEqual(permissivePathRequirement(d), 1);
    }
  });
});

describe('defaultPathRequirement', () => {
  test('distance 1-3 → 1 path', () => {
    assert.strictEqual(defaultPathRequirement(1), 1);
    assert.strictEqual(defaultPathRequirement(2), 1);
    assert.strictEqual(defaultPathRequirement(3), 1);
  });
  test('distance 4 → 2 paths', () => {
    assert.strictEqual(defaultPathRequirement(4), 2);
  });
  test('distance 5+ → 3 paths', () => {
    assert.strictEqual(defaultPathRequirement(5), 3);
    assert.strictEqual(defaultPathRequirement(6), 3);
  });
});

describe('strictPathRequirement', () => {
  test('distance 1-2 → 1 path', () => {
    assert.strictEqual(strictPathRequirement(1), 1);
    assert.strictEqual(strictPathRequirement(2), 1);
  });
  test('distance 3 → 2 paths', () => {
    assert.strictEqual(strictPathRequirement(3), 2);
  });
  test('distance 4+ → 3 paths', () => {
    assert.strictEqual(strictPathRequirement(4), 3);
    assert.strictEqual(strictPathRequirement(5), 3);
  });
});

// ---------------------------------------------------------------------------
// _meetsStrictness
// ---------------------------------------------------------------------------

describe('_meetsStrictness: permissive', () => {
  test('always visible regardless of distance or pathCount', () => {
    assert.ok(_meetsStrictness('permissive', 1, 0));
    assert.ok(_meetsStrictness('permissive', 5, 0));
    assert.ok(_meetsStrictness('permissive', 3, 1));
  });
});

describe('_meetsStrictness: standard', () => {
  test('distance 3, pathCount=1 → visible (default requires 1)', () => {
    assert.ok(_meetsStrictness('standard', 3, 1));
  });
  test('distance 4, pathCount=1 → hidden (default requires 2)', () => {
    assert.ok(!_meetsStrictness('standard', 4, 1));
  });
  test('distance 4, pathCount=2 → visible', () => {
    assert.ok(_meetsStrictness('standard', 4, 2));
  });
  test('distance 5, pathCount=2 → hidden (default requires 3)', () => {
    assert.ok(!_meetsStrictness('standard', 5, 2));
  });
  test('distance 5, pathCount=3 → visible', () => {
    assert.ok(_meetsStrictness('standard', 5, 3));
  });
});

describe('_meetsStrictness: strict', () => {
  test('distance 2, pathCount=1 → visible (strict requires 1)', () => {
    assert.ok(_meetsStrictness('strict', 2, 1));
  });
  test('distance 3, pathCount=1 → hidden (strict requires 2)', () => {
    assert.ok(!_meetsStrictness('strict', 3, 1));
  });
  test('distance 3, pathCount=2 → visible', () => {
    assert.ok(_meetsStrictness('strict', 3, 2));
  });
  test('distance 4, pathCount=2 → hidden (strict requires 3)', () => {
    assert.ok(!_meetsStrictness('strict', 4, 2));
  });
  test('distance 4, pathCount=3 → visible', () => {
    assert.ok(_meetsStrictness('strict', 4, 3));
  });
});

// ---------------------------------------------------------------------------
// _filterEntries
// ---------------------------------------------------------------------------

function makeEntry(tech, visibility = 'default') {
  return { tech, value: `val-${tech}`, visibility };
}

describe('_filterEntries: owner default=standard, requester at distance 3 with 1 path', () => {
  const contact = {
    name: 'Test',
    entries: [
      makeEntry('email', 'default'),    // standard → visible (d3, p1 meets standard)
      makeEntry('phone', 'permissive'), // permissive → always visible
      makeEntry('fax', 'strict'),       // strict → hidden (d3, p1 does not meet strict)
    ],
  };

  test('permissive and standard entries visible, strict hidden', () => {
    const { contact: result, someHidden } = _filterEntries(contact, 'standard', 3, 1);
    const techs = result.entries.map(e => e.tech);
    assert.deepStrictEqual(techs.sort(), ['email', 'phone']);
    assert.ok(someHidden);
  });
});

describe('_filterEntries: owner default=strict, requester at distance 3 with 1 path', () => {
  const contact = {
    name: 'Test',
    entries: [
      makeEntry('email', 'default'),    // inherits strict → hidden
      makeEntry('phone', 'permissive'), // permissive override → visible
      makeEntry('signal', 'standard'),  // standard override → visible
    ],
  };

  test('only permissive and standard-override entries visible', () => {
    const { contact: result, someHidden } = _filterEntries(contact, 'strict', 3, 1);
    const techs = result.entries.map(e => e.tech);
    assert.deepStrictEqual(techs.sort(), ['phone', 'signal']);
    assert.ok(someHidden);
  });
});

describe('_filterEntries: owner default=permissive, requester at distance 4 with 1 path', () => {
  const contact = {
    name: 'Test',
    entries: [
      makeEntry('email', 'default'),   // inherits permissive → visible
      makeEntry('phone', 'standard'),  // standard override, d4 p1 → hidden (needs 2 paths)
      makeEntry('signal', 'strict'),   // strict, d4 p1 → hidden (needs 3 paths)
    ],
  };

  test('only default (permissive) entry visible at distance 4 with 1 path', () => {
    const { contact: result, someHidden } = _filterEntries(contact, 'permissive', 4, 1);
    const techs = result.entries.map(e => e.tech);
    assert.deepStrictEqual(techs, ['email']);
    assert.ok(someHidden);
  });
});

describe('_filterEntries: non-entry fields preserved', () => {
  test('name and notes pass through unchanged', () => {
    const contact = { name: 'Alice', notes: 'hi', entries: [makeEntry('email', 'permissive')] };
    const { contact: result, someHidden } = _filterEntries(contact, 'standard', 1, 1);
    assert.strictEqual(result.name, 'Alice');
    assert.strictEqual(result.notes, 'hi');
    assert.ok(!someHidden);
  });
});

// ---------------------------------------------------------------------------
// BFS path counting accuracy
// ---------------------------------------------------------------------------
//
// Graph: pov → b1 → c1 → target   (path 1)
//        pov → b2 → c2 → target   (path 2, node-disjoint)
//
// target is at distance 3 from pov. defaultPathRequirement(3) = 1, so
// admission only needs 1 path. The BFS must still find both paths so that
// strict-entry checks (which need 2 paths at distance 3) are accurate.

describe('BFS path counting at distance 3', () => {
  const pov = 'pov';
  const b1 = 'b1'; const b2 = 'b2';
  const c1 = 'c1'; const c2 = 'c2';
  const target = 'target';

  function stmt(i, trust) {
    return { I: i, trust, time: '2024-01-01T00:00:00.000Z' };
  }

  const byIssuer = new Map([
    [pov,    [stmt(pov, b1), stmt(pov, b2)]],
    [b1,     [stmt(b1, c1)]],
    [b2,     [stmt(b2, c2)]],
    [c1,     [stmt(c1, target)]],
    [c2,     [stmt(c2, target)]],
    [target, []],
  ]);

  test('target is admitted via defaultPathRequirement (1 path at d3)', async () => {
    const graph = await reduceTrustGraph(pov, byIssuer, { pathRequirement: defaultPathRequirement });
    assert.ok(graph.distances.has(target), 'target should be in graph');
    assert.strictEqual(graph.distances.get(target), 3);
  });

  test('graph stores both node-disjoint paths to target', async () => {
    const graph = await reduceTrustGraph(pov, byIssuer, { pathRequirement: defaultPathRequirement });
    const pathCount = graph.paths.get(target)?.length ?? 0;
    assert.strictEqual(pathCount, 2, `expected 2 paths, got ${pathCount}`);
  });

  test('strict entry at distance 3 with 2 paths → visible', () => {
    assert.ok(_meetsStrictness('strict', 3, 2));
  });

  test('strict entry at distance 3 with only 1 path → hidden', () => {
    assert.ok(!_meetsStrictness('strict', 3, 1));
  });
});
