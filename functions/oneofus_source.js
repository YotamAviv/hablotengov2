const ONEOFUS_EXPORT_URL = process.env.FUNCTIONS_EMULATOR === 'true'
  ? 'http://127.0.0.1:5002/one-of-us-net/us-central1/export'
  : 'https://export.one-of-us.net';

const oneofusSource = {
  async fetch(fetchMap) {
    const results = {};
    const tokens = Object.keys(fetchMap);
    if (tokens.length === 0) return results;

    const spec = JSON.stringify(tokens.map(t => ({ [t]: null })));
    const url = `${ONEOFUS_EXPORT_URL}?spec=${encodeURIComponent(spec)}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`oneofus export failed: ${res.status}`);

    const text = await res.text();
    for (const line of text.trim().split('\n')) {
      if (!line) continue;
      const obj = JSON.parse(line);
      for (const [token, statements] of Object.entries(obj)) {
        results[token] = Array.isArray(statements) ? statements : [];
      }
    }
    for (const t of tokens) {
      if (!results[t]) results[t] = [];
    }
    return results;
  },
};

module.exports = { oneofusSource };
