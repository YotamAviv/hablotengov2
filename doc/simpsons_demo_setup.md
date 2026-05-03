# Simpsons Demo Data Setup

Creates the Simpsons 
Nerdster scripts create:
- identities and nerdster delegates in oneofus
- content data in nerdster
Hablo scripts create:
- hablo delegates in oneofus
- contact data in hablo

Run the nerdster step first — it produces the key files that hablotengo consumes.

Hablo's been a bigger pain because:
- it's mostly implemented in JavaScript cloud functions and so requires more integration testing.
- it has more cloud functions, and so the emulator is slow to start
- its testing changes database state and needs to be restored between runs.
- its data is protected, and so it requires disabling protection guards to write the demo data.

---

## On the emulator

### 1. Start emulators empty

```
cd ~/src/github/nerdster14   && bin/start_emulator.sh --empty
cd ~/src/github/oneofusv22   && bin/start_emulator.sh --empty
cd ~/src/github/hablotengo   && bin/start_emulator.sh --empty
```

### 2. Create nerdster and oneofus demo data

```
cd ~/src/github/nerdster14
bin/createSimpsonsDemoData.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

### 3. Generate Hablo key files

```
cd ~/src/github/hablotengo
python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py
```

Generates `lib/dev/simpsons_public_keys.dart`, `lib/dev/simpsons_private_keys.dart` (gitignored), and `functions/simpsons_keys.json` from the JSON files produced in step 2.

### 4. Create Hablo contact data

```
cd ~/src/github/hablotengo
bin/createSimpsonsContactData.sh
```

Reads the key files above. Pushes Hablo delegate keys to oneofus and writes contact data to hablotengo.

---

## On production

### 1. Create nerdster demo data

```
cd ~/src/github/nerdster14
bin/createSimpsonsDemoData_prod.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

### 2. Generate Hablo key files

```
cd ~/src/github/hablotengo
python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py
```

Generates `lib/dev/simpsons_public_keys.dart`, `lib/dev/simpsons_private_keys.dart` (gitignored),
and `functions/simpsons_keys.json`.

### 3. Temporarily disable the demo write guard and deploy

In `functions/set_my_contact.js`, comment out the block:
```js
// if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
//   res.status(403).send('Demo users cannot write in production');
//   return;
// }
```

Then deploy:
```
cd ~/src/github/hablotengo
firebase deploy --only functions:setMyContact,functions:demoSignIn
```

`demoSignIn` needs redeployment because `simpsons_keys.json` was regenerated in step 2.

### 4. Create Hablo contact data

```
cd ~/src/github/hablotengo
bin/createSimpsonsContactData_prod.sh
```

### 5. Re-enable the demo write guard and redeploy

Restore `functions/set_my_contact.js` and redeploy:
```
firebase deploy --only functions:setMyContact
```

### 6. Deploy hablotengo web app  (critical for demo)

```
cd ~/src/github/hablotengo
bin/deploy_web.sh
```

Required because `simpsons_public_keys.dart` (compiled into the web app) contains the new identities.

### 7. Commit and deploy nerdster and oneofus (less critical)

Commit `web/common/data/demoData.js` in nerdster and deploy:
bin/deploy_web.sh

Commit  `web/common/data/demoData.js` in oneofus and deploy:
firebase --project=one-of-us-net deploy --only hosting
