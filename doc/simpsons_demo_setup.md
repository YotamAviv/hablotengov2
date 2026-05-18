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
cd ~/src/github/nerdster   && bin/start_emulator.sh --empty
cd ~/src/github/oneofus    && bin/start_emulator.sh --empty
cd ~/src/github/hablotengo && bin/start_emulator.sh --empty
cd ~/src/github/oneofus   && bin/start_karennet_emulator.sh
```

Karennet (port 8083/5004) is required for Marge and Luann's trust statements.
Verify all are up: `cd ~/src/github/nerdster && bin/emulators_status.sh`

### 2. Create nerdster, oneofus, and karennet demo data

```
cd ~/src/github/nerdster
bin/createSimpsonsDemoData.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

After this, update the hardcoded Lisa identity in
`integration_test/ui_test.dart` to match the new key printed in the generator output.

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

### 1. Create nerdster demo data (identities, delegate keys, content data)

```
cd ~/src/github/nerdster
bin/createSimpsonsDemoData_prod.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

### 2. Create Hablo demo data (delegate keys, contact data)

```
cd ~/src/github/hablotengo
bin/createSimpsonsContactData_prod.sh
```

This generates the key files (`lib/dev/simpsons_public_keys.dart`,
`lib/dev/simpsons_private_keys.dart`, `functions/simpsons_keys.json`) and writes
contact data to production. It authenticates using a real Ed25519 session signature
(not the demo guard), so no guard disable/redeploy is needed.

### 4. Deploy and commit

cd ~/src/github/oneofus
cp ~/src/github/nerdster/web/common/data/demoData.js web/common/data/demoData.js

cd ~/src/github/hablotengo
firebase deploy --only functions --project=hablotengo

`simpsons_public_keys.dart` is compiled into the Hablo web app.

In each project
```
bin/deploy_web.sh
```

