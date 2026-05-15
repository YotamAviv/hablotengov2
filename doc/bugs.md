# Bug List

This laundry list of issues came up yesterday evening as we were trying to figure out why my contact card is not being either saved or retrieved properly.
The root cause was that my Android ONE-OF-US.NET app ended up with a delegate key stored on the device that was not associated with my identity (there was no delegate statement for it in Firebase).

There is an inherent challenge as the storage has:
- private / public key pairs: Flutter secure storage on device
- delegate statements mapping my identity to my delegate keys: Firebase

This  is not related to emulator/production.

What not to do:
- encourage this from happening again
  - the apps (Hablo, Nerdster) should reject this sitation quickly.
  - the identity phone app should reject this situation quicly
- tolerate this
  - AI agent tried to tolerate this and to accommodate this sitation. We shouldn't.

Some of what the AI agent tried to do to fix this was to deal with it instead of failing quickly. Those changes should be reverted.

## OOU (one-of-us.net phone app)

**rep invariant for local delegate keys**
A key in local storage is a delegate key if its domain is not one-of-us.net.
We should have an active delegate statement (these are listed on the SERVICES screen) for every delegate key in local storage.

If we don't, then offer the **CLAIM** or **DELETE** options described below.

If this rep invariant is not met, then I don't think we should allow for anything other than refresh (load data from Firebase) and should be showing a dialog offering the options above.

This rep invariant should be checked whenever we load data or publish a statement.
In some ways we also check it before publishing a statement, for example if we're about to clear a delegate key (the same could be done if we're about to clear a delegate key by trusting or blocking it, but that'd be going overboard. That's rare, and the regular check invariant path should catch that later.)

### App shows "Me" initially before loading finishes
When the phone loads up it shows "Me" until something async happens.
If we haven't loaded any Firestore statements yet, then make it clear that we're loading.
Do not show the wrong thing until we have the right thing.

### 2. Sign-in did not verify the local delegate key is registered in OOU
When `keys.delegate(domain)` returned a non-null key pair, the old `SignInService.signIn`
sent it directly to the service without checking `myStatements`. If the local key and
OOU's registered key were out of sync for any reason, sign-in silently succeeded but the
service could not find the user's data. **Fixed:** block sign-in with an error if the
local key is not in `myStatements`.

HUMAN:
This violates **rep invariant** and should be found before the sign in attempt.

### 5. "Delegate key not registered" error offers no actionable options

When sign-in is blocked because the local delegate key is not in OOU, the error dialog
only shows COPY and OKAY — a dead end. The user already has the key locally, so the app
should offer two actions inline:
- **Claim** — publish an OOU delegate statement for the key already on this device,
  then retry sign-in. No new key is created; this just registers what is already here.
- **Delete** — remove the orphaned key from local `Keys` secure storage, so the next
  sign-in attempt starts fresh (no local key → rotation flow).

HUMAN: The app should check **rep invariant for local delegate keys**, see above.

---

## Hablotengo
