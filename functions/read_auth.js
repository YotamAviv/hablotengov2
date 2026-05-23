const { authenticate } = require('./auth_util');
const { TrustPipeline } = require('./trust_pipeline');
const { oneofusSource, federatedSourceFor } = require('./oneofus_source');

/**
 * Auth hook for Hablo's export endpoint.
 *
 * Authenticates the viewer and checks that they are reachable in the target
 * identity's ONE-OF-US trust graph. The spec encodes the target:
 *   spec = "${delegateToken}_${identityToken}"   (plain string or JSON array)
 *   auth = JSON.stringify({identity, sessionTime, sessionSignature})
 */
async function habloExportAuthHook(req, res) {
  const { auth: authParam, spec: specParam } = req.query;

  if (!authParam) { res.status(400).send('Missing auth'); return null; }
  let authPacket;
  try {
    authPacket = JSON.parse(decodeURIComponent(authParam));
  } catch {
    res.status(400).send('Invalid auth JSON'); return null;
  }

  const authResult = authenticate(authPacket, 'read', res);
  if (!authResult) return null;
  const viewerToken = authResult.identityToken;

  if (!specParam) { res.status(400).send('Missing spec'); return null; }

  // Extract the target identity token from the stream key.
  // Spec may arrive as a plain string or a JSON array (from ChannelFactory).
  let streamKey;
  try {
    const specString = decodeURIComponent(specParam);
    const parsed = /^\s*\[/.test(specString) ? JSON.parse(specString) : specString;
    const first = Array.isArray(parsed) ? parsed[0] : parsed;
    streamKey = typeof first === 'object' ? Object.keys(first)[0] : first;
  } catch {
    res.status(400).send('Invalid spec'); return null;
  }

  const sep = streamKey.lastIndexOf('_');
  if (sep === -1) { res.status(400).send('Invalid spec: expected delegateToken_identityToken'); return null; }
  const targetIdentityToken = streamKey.substring(sep + 1);

  if (viewerToken !== targetIdentityToken) {
    try {
      const fedRegistry = new Map();
      const viewerPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      await viewerPipeline.build(viewerToken, { fedRegistry });
      const targetPipeline = new TrustPipeline(oneofusSource, { sourceFor: federatedSourceFor });
      const graph = await targetPipeline.build(targetIdentityToken, { fedRegistry });
      if (!graph.distances.has(viewerToken)) { res.status(403).send('Not trusted'); return null; }
    } catch (e) {
      console.error('[read_auth] trust check error:', e.message);
      res.status(500).send(e.message); return null;
    }
  }

  return { viewerToken };
}

module.exports = { habloExportAuthHook };
