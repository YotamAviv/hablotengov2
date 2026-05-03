# TODO

## Not allow us to deceive or be a silo

An architectural change

The Nerdster presents a signed cryptographic chain from your key to all content.

Hablo would need to replace the private nonce with a public none or nonce alternative, sort of like a delegate

People could revoke or clear these with their identity app (like revoking or clering delegate keys)

Hablo 
- would respect revoked nonce/delegates.
- would show proof from your identity to data (other user signed nonce/delegation to hablotengo.com)

Other services could receive signed autorization to interact with Hablo: read contacts, maybe write/update, Hablo would authenticate and oblige



## Simpsons demo data - don't create multiple delegate keys

Sometimes we run the hablo creation more than once. It shouldn't create a delegate key if a delegate statement already exists.

## MOOT, BUT LEAVE HERE AS A NOTE, DO NOT DELETE: Re-create PROD simpsons data and files

TODO: Consider writing the simpsons identities to the database.

Think about how to address so that we can
- fix a bug and push
- run the tests without trashing files we need to push
Solution:
- revert the generated data files