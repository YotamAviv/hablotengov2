# Plan

This doc is newer than design.md.
It is more accurate in terms of what we'll actually build and has less discussion about options.

## Starting

- sign in flow, almost identical to Nerdster but with verified identity token provable to server.
- create (save to Firestore) demo contact data leveragiong existing SimpsonsDemo connecctions from Nerdster's run available in Firestore, just add the contact info - similar to what was deleted in lib/dev/simpsons_demo.
- sign in as Simpson's characters test data using Android emulator importing Simpsons chars' private identity key pairs.
  - Android emulator and Dart webapp running on my development machine both connected to Firebase emulators.
  - keymeid:// works on this machine using scripts, see documentation in Nerdster dir (magic.md "The Bridge Script").
- Do not focus on presenting the data on screen yet, just show it as JSON directly from Firestore.
- get server interactions working
  - cloud functions can authenticate session token (phone identity app signed nonce'ish thing with identity private key)
  - cloud functions allow editing sign in user's data
  - cloud functions allow serving contact data if access rules allow (server runs Greedy BFS form contact's PoV, computes how trusted signed in user is, serves portions of contact data that are allowed to be seen as Json.)

## contact info data model

- Name
  - text box
  - allowed delimiters: ["-" "(" ")" ",", "\"", "\'"] 
    - quotes must match.
- Notes
  - free form text (eg. "Don't call me" -Homer, "Call me!!!" -Marge).

- key/value pairs
key is tech: email, insta, phone, ..
value is always a list of value objects
- the value is the value (ie. yotam@aviv.net) - text box
- bools and enums (shown as icons in UI):
  - preferred (or not) - click through to cycle
  - visiblity override (permissive, standard, strict, <default>) - click through to cycle
  - move up/down in list
  - X - delete

## Contact info view
Try to look like vCard.
- tight, compact, business like

## Demo accounts
- hard coded Simpsons (definitely on server, possibly in client why not)
- Don't require verifying identity
- All data read only

## Settings
- gear icon always visible, probably top right
- <default> visibility
- delete account

## search matches any string in any field
- name
- monikers
- email address, insta handles, etc..

## popup that must be dismissed if have !disabled equivalents
- disabler (if not you (or equiv))
  - key
  - link to disabler view on Nerdster
- options
  - merge and disable
    Merges all fields unless strict duplicates. You can X them out.
  - dismiss (leaves disabled, won't show again, notes that you dismissed somewhere, probably in your account)

## Simpsons
Use them from the Nerdster.
Add contact info.
We might need to add a new set for testing/developing replace conflicts and such.

## Security
Server requires proof of identity
- to serve info, runs Greedy BFS from your proven identity.
- to update info, manage account

## Algorithm

We need to run Greedy BFS from each contact's PoV.
- Initially, just do that. 
  Might not even be slow especially considering network size and that folks trust each other in groups and so cache hits are expected to be high.
- A performance improvement would be to run them in parallel and group server statement fetches.

## Roladex
Fancy view like the Mac wheel thing

Sort by last name
- Last name is the last string not in parens

