# TODO

## Delete account

We need to delete any replaced, equiavlent accounts, too.
But only if those accounts (identities) believe their yours.
(If we don't, then when you sign in after deleting your account, you'll see yourself, your equivalent accounts)

## Link to Nerdster for investingating, clearing or blocking vouch

The Nerdster will need url param upgrades to support this
Show graph for 
- You (PoV) to target
- target to you

## The Hablo client seems to shows data before it's ready to show

It looks like 
- we see monikers before the cards are ready
- we see folks without cards before they're cleared (unless the setting says to show folks without cards)

It's confusing and looks sloppy.
I'd prefer a loading icon until things are ready.
It's slow in general and seems unresponsive.

A general loading icon at the top bar that always displays a loading status if we have any async calls out would help with much of this.

## Re-create PROD simpsons data and files

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
