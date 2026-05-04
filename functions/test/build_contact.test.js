const { test, describe } = require('node:test');
const assert = require('node:assert');

const { _replayStatements } = require('../build_contact');

function stmt(set, time = '2024-01-01T00:00:00.000Z') {
  return { set, time };
}

describe('_replayStatements: empty', () => {
  test('returns default contact when no statements', () => {
    const c = _replayStatements([]);
    assert.strictEqual(c.name, '');
    assert.deepStrictEqual(c.entries, []);
    assert.strictEqual(c.showEmptyCards, false);
    assert.strictEqual(c.showHiddenCards, false);
    assert.strictEqual(c.defaultStrictness, 'standard');
    assert.ok(!('notes' in c));
  });
});

describe('_replayStatements: snapshot', () => {
  test('single snapshot sets name and entries', () => {
    const c = _replayStatements([
      stmt({ name: 'Alice', entries: [{ tech: 'email', value: 'a@example.com' }] }),
    ]);
    assert.strictEqual(c.name, 'Alice');
    assert.deepStrictEqual(c.entries, [{ tech: 'email', value: 'a@example.com' }]);
  });

  test('second snapshot overwrites entries from first', () => {
    const c = _replayStatements([
      stmt({ name: 'Alice', entries: [{ tech: 'email', value: 'old@example.com' }] }, '2024-01-01T00:00:00.000Z'),
      stmt({ name: 'Alice', entries: [{ tech: 'phone', value: '+1-555-0100' }] }, '2024-01-02T00:00:00.000Z'),
    ]);
    assert.deepStrictEqual(c.entries, [{ tech: 'phone', value: '+1-555-0100' }]);
  });

  test('snapshot entries array order is preserved', () => {
    const entries = [
      { tech: 'phone', value: '111' },
      { tech: 'email', value: 'a@b.com' },
      { tech: 'signal', value: 'handle' },
    ];
    const c = _replayStatements([stmt({ name: 'Bob', entries })]);
    assert.deepStrictEqual(c.entries.map(e => e.tech), ['phone', 'email', 'signal']);
  });

  test('notes stored when present', () => {
    const c = _replayStatements([stmt({ name: 'A', notes: 'Call after 6pm', entries: [] })]);
    assert.strictEqual(c.notes, 'Call after 6pm');
  });

  test('notes not in result when never set', () => {
    const c = _replayStatements([stmt({ name: 'A', entries: [] })]);
    assert.ok(!('notes' in c));
  });
});

describe('_replayStatements: settings accumulate alongside snapshots', () => {
  test('showEmptyCards set after snapshot is picked up', () => {
    const c = _replayStatements([
      stmt({ name: 'A', entries: [] }, '2024-01-01T00:00:00.000Z'),
      stmt({ showEmptyCards: true }, '2024-01-02T00:00:00.000Z'),
    ]);
    assert.strictEqual(c.showEmptyCards, true);
  });

  test('defaultStrictness updated independently of contact snapshot', () => {
    const c = _replayStatements([
      stmt({ name: 'B', entries: [{ tech: 'email', value: 'b@b.com' }] }, '2024-01-01T00:00:00.000Z'),
      stmt({ defaultStrictness: 'strict' }, '2024-01-02T00:00:00.000Z'),
    ]);
    assert.strictEqual(c.defaultStrictness, 'strict');
    assert.deepStrictEqual(c.entries, [{ tech: 'email', value: 'b@b.com' }]);
  });

  test('latest setting wins when set multiple times', () => {
    const c = _replayStatements([
      stmt({ showHiddenCards: true }, '2024-01-01T00:00:00.000Z'),
      stmt({ showHiddenCards: false }, '2024-01-02T00:00:00.000Z'),
    ]);
    assert.strictEqual(c.showHiddenCards, false);
  });
});

describe('_replayStatements: legacy enter/clear', () => {
  test('enter with no snapshot produces legacy entries sorted by order', () => {
    const c = _replayStatements([
      { enter: 'slot1', with: { order: '2', tech: 'phone', value: '+1-555' }, time: '2024-01-01T00:00:00.000Z' },
      { enter: 'slot2', with: { order: '1', tech: 'email', value: 'x@y.com' }, time: '2024-01-01T00:00:00.000Z' },
    ]);
    assert.deepStrictEqual(c.entries.map(e => e.tech), ['email', 'phone']);
  });

  test('clear removes a legacy entry', () => {
    const c = _replayStatements([
      { enter: 'slot1', with: { order: '1', tech: 'email', value: 'x@y.com' }, time: '2024-01-01T00:00:00.000Z' },
      { clear: 'slot1', time: '2024-01-02T00:00:00.000Z' },
    ]);
    assert.deepStrictEqual(c.entries, []);
  });

  test('snapshot after legacy enter replaces all legacy entries', () => {
    const c = _replayStatements([
      { enter: 'slot1', with: { order: '1', tech: 'email', value: 'old@example.com' }, time: '2024-01-01T00:00:00.000Z' },
      stmt({ name: 'Alice', entries: [{ tech: 'phone', value: '555' }] }, '2024-01-02T00:00:00.000Z'),
    ]);
    assert.deepStrictEqual(c.entries, [{ tech: 'phone', value: '555' }]);
  });
});
