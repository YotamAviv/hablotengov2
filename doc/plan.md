# Plan

This doc is newer than design.md.
It is more accurate in terms of what we'll actually build and has less discussion about options.

## Starting ✅

- ✅ sign in flow, almost identical to Nerdster but with verified identity token provable to server.
- ✅ create (save to Firestore) demo contact data leveraging existing Simpsons connections from Nerdster's run available in Firestore, just add the contact info - similar to what was deleted in lib/dev/simpsons_demo.
- ✅ sign in as Simpson's characters test data using Android emulator importing Simpsons chars' private identity key pairs.
  - Android emulator and Dart webapp running on my development machine both connected to Firebase emulators.
  - keymeid:// works on this machine using scripts, see documentation in Nerdster dir (magic.md "The Bridge Script").
- ✅ get server interactions working
  - ✅ cloud functions can authenticate session token (phone identity app signed nonce'ish thing with identity private key)
  - ✅ cloud functions allow editing sign in user's data
  - ✅ cloud functions allow serving contact data if access rules allow (server runs Greedy BFS from contact's PoV, computes how trusted signed in user is, serves portions of contact data that are allowed to be seen as Json.)

## contact info data model

- ✅ Name
  - text box
  ✅ Notes
  - free form text (eg. "Don't call me" -Homer, "Call me!!!" -Marge).

- ✅ key/value pairs
key is tech: email, insta, phone, ..
value is always a list of value objects
- ✅ the value is the value (ie. yotam@aviv.net) - text box
- bools and enums (shown as icons in UI):
  - ✅ preferred (or not) - click through to cycle
  - ✅ visibility override (permissive, standard, strict, \<default>) - color-coded pill picker; tapping selected deselects to default
  - ✅ drag to reorder (tech label is drag handle)
  - ✅ X - delete

## Contact info view
Try to look like vCard.
- tight, compact, business like

> ⚠️ Currently a bottom sheet with a plain list. Not vCard-styled yet.

## Demo accounts
- ✅ hard coded Simpsons (definitely on server, possibly in client why not)
- ✅ Don't require verifying identity
- ✅ All data read only on production (emulator allows writes for reseeding)
  - `setMyContact` returns 403 for demo users when `FUNCTIONS_EMULATOR !== 'true'`

## Settings
- ✅ gear icon always visible, top right
- ✅ \<default> visibility — color-coded pill picker with help button
- ❌ delete account

## search matches any string in any field ✅
- ✅ name
- ✅ monikers
- ✅ email address, insta handles, etc..

## popup that must be dismissed if have !disabled equivalents ❌
- Show who the disabler is if it wasn't you (equiv also counts as you).
  - show key, like Nerdster (JsonQrDisplay, already in oneofus_common).
  - DEFER: Include link to his view on Nerdster
- Offer these options:
  - Merge data and disable storage (account) of equivalent key
    - Merges all fields from equiavlent account(s) into canonical account unless they're exact duplicates. (If they're near duplicates, the user can clean it up himself.)
    - Mark this account as disabled by you (your canonical key, how you're currently signed in).
  - Dismiss
    Does nothing other than noting (in your account) that you've dismissed this issue and don't care to be shownn issues about it again.

Also do:
- Never even consider including disabled accounts as equivalent accounts when selecting data to show.
- Alert a user if he actually signs in to a disabled account. 
  - Show him the disabler and allow him to enable (un-disable) the account.
  - (Only he can enable the account. We can't know who's account this really is unless someone signs in with the private key.)

Notes:
- When keys are lost, accounts for those keys can only be disabled once and can't be enabled ever once they're disabled (since the keys are lost).


## Simpsons ✅
- ✅ Use them from the Nerdster.
- ✅ Add contact info.
- ❌ We might need to add a new set for testing/developing replace conflicts and such.

## Security ✅
- ✅ Server requires proof of identity
- ✅ to serve info to others, runs Greedy BFS from your proven identity to theirs to check if they have access.
- ✅ only you can update your own info, manage account

## Algorithm ✅

- ✅ Run Greedy BFS from each contact's PoV.
- ✅ Performance improvement: run in parallel and group server statement fetches (MultiTargetTrustPipeline).

> ⚠️ Visibility strictness went further than the plan described: graph admission uses permissive
> (anyone reachable by any path gets in), then per-entry filtering gates each field by the owner's
> defaultStrictness and per-entry visibility override against the requester's actual path count.
> A "Some fields hidden due to access restrictions" notice appears when entries are filtered.
> This is consistent with the data model plan but was not spelled out at the algorithm level.

## Contacts list
- ✅ Sort by last name, middle, first (using card name when available, falling back to trust-graph moniker)
- ✅ Signed-in user appears in their own contacts list; tapping opens their own editable card

## Roladex ✅ (in roladex branch)
Fancy view like the Mac wheel thing

## Public web page, deploy script(s) ❌
Like https://nerdster.org, https://nerdster.org/app, this project should have an informational web page at https://hablotengo.com and the online web app available at https://hablotengo.com/app.
Use a similar strategy and set of scripts like the Nerdster's.

## Export as vCard? ❌
Include 
- public identity key
- monikers
