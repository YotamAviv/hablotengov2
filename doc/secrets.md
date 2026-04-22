
Reality:
- anyone (bad actors included) can
  - create an identity key
  - claim anyone's identity key as yours (publish and sign a replace statement)
  - claim anyone's delegate key as yours (publish and sign a delegate statement)
  - create bogus identity that vouch for your bogus identity

Fears:
- Someone can willy-nilly sign in as you and see your info, hijack your account
  - probably can be stopped.
- Someone steals your phone and tries to hijack your account before you
  - rotate your identity key
  - tell your friends
  - and have your new identity sufficiently vouched for
  Probably can't be stopped.
- Someone in your network claims your key fraudulently and interrupts your service
  - Hmm..


Propsed model:

Storage:
- signed delegate key statements with contact info
- root account identity keys (1 per account) for grounding.

Signs in:
- require proof of owning an identity (signature challenge)

Compute your equivalent keys from your PoV.

If none of your canonical and equivalent keys match a grounded account key:
Create a new account and ground it.

If exactly your canonical key matches a grounded account key and none of your equivalent keys match
Staight forward case, you have an account, good to go.

If exactly one of your equivalent keys matches a single grounded account key
You probably rotated your key.
- Compute the network from the grounded key's PoV
- if it trusts your new key sufficiently, then alert you and update the grounding key.
- if not, don't allow using that grounded identity account. 
- Alert you - you new key needs more vouches from the old key's network
You're locked out until you do. (We can't send you a 6 digit code.)

If more than one of your equivalent or canonical keys match grounded account keys:
Hmmm... You probably made a mess, or maybe you're doing something bad.
Can check if those grounded account keys trust your new key. If they all do, then offer a consolidation to 1 account.

Hopes and desires:
No one can hijack your account or see your info without having you and your own network fail at their jobs.