/**
 * Generates trust_fixture.json and trust_characters.json from the ONE-OF-US.NET export.
 *
 * Run from the functions/ directory:
 *   node test/generate_trust_fixtures.js
 *
 * After this, run the Dart golden generator:
 *   flutter test test/logic/trust_golden_generator_test.dart
 */

const fs = require('fs');
const path = require('path');
const { getToken } = require('../jsonish_util');

// Load demoData.js as a module — strip the JS wrapper and parse as JSON.
const demoDataPath = path.join(__dirname, '../../web/common/data/demoData.js');
const vm = require('vm');
const demoDataSource = fs.readFileSync(demoDataPath, 'utf8');
// Execute the JS file in a sandbox; rewrite 'const demoData' as a global assignment
const context = {};
vm.runInNewContext(demoDataSource.replace('const demoData', 'demoData'), context);
const demoData = context.demoData;

function isIdentityKey(name, value) {
  if (value.statement) return false;
  if (!value.crv) return false;
  if (/-nerdster\d+$/.test(name)) return false;
  return true;
}

const EXPORT_URL = 'http://127.0.0.1:5004/one-of-us-net/us-central1/export';

async function main() {
  // Compute tokens for all identity characters
  const characters = {};
  for (const [name, value] of Object.entries(demoData)) {
    if (isIdentityKey(name, value)) {
      characters[name] = await getToken(value);
    }
  }

  const tokens = Object.values(characters);
  console.log(`Fetching ${tokens.length} identity keys from export...`);

  // Batch fetch: pass all tokens as a JSON array
  const spec = encodeURIComponent(JSON.stringify(tokens.map(t => ({ [t]: null }))));
  const url = `${EXPORT_URL}?spec=${spec}&distinct=true`;
  const response = await fetch(url);
  const text = await response.text();

  // Parse NDJSON (one line per token)
  const fixture = {};
  for (const line of text.trim().split('\n')) {
    if (!line) continue;
    const obj = JSON.parse(line);
    const [token, statements] = Object.entries(obj)[0];
    fixture[token] = statements;
  }

  fs.writeFileSync(
    path.join(__dirname, 'trust_fixture.json'),
    JSON.stringify(fixture, null, 2)
  );
  fs.writeFileSync(
    path.join(__dirname, 'trust_characters.json'),
    JSON.stringify(characters, null, 2)
  );

  console.log(`Wrote trust_fixture.json (${Object.keys(fixture).length} keys)`);
  console.log(`Wrote trust_characters.json (${Object.keys(characters).length} characters)`);
  console.log('Now run: flutter test test/logic/trust_golden_generator_test.dart');
}

main().catch(e => { console.error(e); process.exit(1); });
