# TODO

## The Hablo client seems to shows data before it's ready to show

It looks like we see monikers before the cards are ready, then some go away some change when they're loaded
When we don't know what's going on yet (who has data / data that's visible to us) paint the monikers in a gray that hints that they're still arriving / loading / being computed.

Add general loading icon at the top bar that displays a loading status iff we have any async calls out.

## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files