# TODO

## Phone app should require version: 2.0.37+137

I believe we implemented such a thing where we set the minimal version in a firebase variable or something.
Find it.
Let me try it.
Then use it.

## Promote Hablo

Update web sites to mention it.

Add to Hablo home:
Instead of keeping track of all of your contacts' latest info, just update your own and let them update theirs.

## Link Hablo to Nerdster for investingating, clearing or blocking vouch

The Nerdster will need url param upgrades to support this
Show graph for 
- You (PoV) to target
- target to you

## Link Nerdster to Hablo

Show a contact info link to Hablo in Nerdster' NodeDetails if delegate key exists.

## The Hablo client seems to shows data before it's ready to show

It looks like 
- we see monikers before the cards are ready
- we see folks without cards before they're cleared (unless the setting says to show folks without cards)

It's confusing and looks sloppy.
I'd prefer a loading icon until things are ready.
It's slow in general and seems unresponsive.

A general loading icon at the top bar that always displays a loading status if we have any async calls out would help with much of this.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files