# TODO

## BUG? Do we show statements when fields are hidden?

## Demo hidden fields

Find or create a case where there are hidden fields.

Consider removing that feature and its complexity.

Can't show crypto proofs if fields are hidden.

Show me:
- who I trust at permissive / standard / strict / who can see my info at what level.
- on someone's card, show how much they trust me.

## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files