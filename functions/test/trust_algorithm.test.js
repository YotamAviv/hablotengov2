const { test, describe } = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { TrustPipeline, defaultPathRequirement } = require('../trust_algorithm');

const fixture = require('./trust_fixture.json');
const golden = require('./trust_golden.json');

// Fixture-backed source: returns statements from the pre-generated JSON.
function makeFixtureSource() {
  return {
    async fetch(fetchMap) {
      const result = {};
      for (const token of Object.keys(fetchMap)) {
        result[token] = fixture[token] || [];
      }
      return result;
    }
  };
}

describe('Trust Algorithm (JS vs Dart golden)', () => {
  for (const [name, expected] of Object.entries(golden)) {
    test(`${name}'s PoV matches Dart`, async () => {
      const source = makeFixtureSource();
      const pipeline = new TrustPipeline(source, { pathRequirement: defaultPathRequirement });
      const graph = await pipeline.build(expected.token);

      assert.deepStrictEqual(
        graph.orderedKeys,
        expected.orderedKeys,
        `orderedKeys mismatch for ${name}`
      );
    });
  }
});
