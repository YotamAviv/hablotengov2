
HabloTengo

Leverage the identity network to allow folks to publish their contact info visible only to folks they trust

Contact info
- name
- email(s): for these, include if they're preferred
- phone number
- contact preferences
  - for each of these include if it's preferred
  - whatsapp
  - signal
  - telegram
  - twitters
    - X.com
    - threads
    - mastodon
    - bluesky
  - instagram
- social accounts  
  - facebook
  - linkedin
- website
- other

The app should make it easy, if possible, to directly link to other folks' Insta, Twitter, etc. accounts. I'm not sure what makes sense here, and it probably depends on the particular service

Visbility
Unlike the Nerdster, HabloTengo will not publish signed statements public for others to read willy-nilly.
It will store its data in its own private storage
It will allow others to see your contact info is you trust them enough (similar to Nerdster's trust levels - permissive, standard, strict). This means that we need to compute both 
- the signed in user's trust graph
- if those in the signed in user's graph trust the signed in user enough to show him their contact info.

I have secured the domain hablotengo.com
I plan to use the same tech stack as Nerdster
