# TODO

## Minor

Use hint "Name" in the name field when editing contact card.

## Home page
Embed the demo.

Add note below that you can sign out and sign in as someone else, change settings (but someone else might be too), ..

Remove the Demo link.

## Home page 2

AI: In your own words and in 3 sentences or less describe HabloTengo with a minor effor on contrasting it to the Nerdster.
Now translate that into Spanish and Spanglish.
Put the results in a tabbed view under the demo with the Spanglish titled HabloTengo.


## CI/CD

Set up GitHub Actions for deployment. When doing so, use Workload Identity
Federation (OIDC) instead of a long-lived `FIREBASE_SERVICE_ACCOUNT` secret:
- GitHub Actions gets a short-lived OIDC token per run
- GCP trusts tokens from this specific repo/branch
- Nothing to leak
- ~5 CLI commands to set up; update `deploy.yml` to use `google-github-actions/auth`
