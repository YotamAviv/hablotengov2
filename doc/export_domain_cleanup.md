# Cleanup: export.hablotengo.com naming confusion

## Problem

`export.hablotengo.com` is a Cloud Run domain mapping that points to the
`exportcontact` function. But the channel factory uses `export.hablotengo.com`
as the logical name for the *authenticated statement stream* (the `export`
function). Two different things share the same domain name.

The write path currently works via a `registerRedirect` workaround in
`main.dart` and `simpsons_demo.dart` that routes `export.hablotengo.com` to
`us-central1-hablotengo.cloudfunctions.net/export` directly.

## Fix (no DNS wait needed)

`exportContact` is already in the Firebase Hosting rewrites at `/exportContact`,
so `https://hablotengo.com/exportContact` works today without any Cloud Run
domain mapping. The `export.hablotengo.com` mapping is redundant for it.

Changing an *existing* Cloud Run domain mapping is instant (no DNS record
change). Adding a *new* domain would require DNS propagation — this plan avoids
that.

### Steps — two-phase due to browser caching

`exportContact` is low-traffic and non-critical (sharing your public key card),
so a broken period for stale clients is acceptable. Still, deploy the code
change well before cutting over the Cloud Run mapping.

**Phase 1 — deploy code, no infra change:**

1. Update `habloExportContactUrl(false)` in `lib/constants.dart` to
   `'https://hablotengo.com/exportContact'` (uses existing Hosting rewrite).

2. Remove the prod `registerRedirect`s for `export.hablotengo.com` and
   `write.hablotengo.com` from `lib/main.dart` and `lib/dev/simpsons_demo.dart`.

3. Deploy web app (`bin/deploy_web.sh`).

Wait several days for most users to pick up the new service worker.

**Phase 2 — infra cutover (instant, no DNS change):**

4. Change the `export.hablotengo.com` Cloud Run domain mapping from
   `exportcontact` → `export` function.

5. Optionally add a `write.hablotengo.com` Cloud Run domain mapping → `write`
   function (for symmetry), or keep using the direct CF URL via redirect.

### Result

- `export.hablotengo.com` → `export` function (authenticated statement stream)
- `write.hablotengo.com` → `write` function
- `exportContact` served at `hablotengo.com/exportContact` via Hosting rewrite
- No `registerRedirect` workarounds in prod
