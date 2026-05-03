# TODO

## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## Explain and show a picture for visibility

Show a contact info link to Hablo in the Nerdster's NodeDetails if Hablo delegate key exists.

Add/change text on the "?" help.

Change the text. I think that it's all wrong.
First, Read the code and accurately describe to me: permissive, standard, strict.

Add: You have a general default visibiliy setting which can be overriden per field (eg. email: permissive, phone: strict).

Add a network diagram of acceptible scenarios:
Permissive:
A -> B -> C -> D -> E -> F

Standard:
A->B
A->B->C
or
A->B->C
A->B1->C

Strict...

## Link Nerdster to Hablo — DONE

Show a contact info link to Hablo in the Nerdster's NodeDetails if Hablo delegate key exists.

## The Hablo client seems to shows data before it's ready to show

It looks like 
- we see monikers before the cards are ready
- we see folks without cards before they're cleared (unless the setting says to show folks without cards)

It's confusing and looks sloppy.
I'd prefer a loading icon until things are ready.
It's slow in general and seems unresponsive.

A general loading icon at the top bar that always displays a loading status if we have any async calls out would help with much of this.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files