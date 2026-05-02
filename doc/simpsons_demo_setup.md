# Simpsons Demo Data Setup

Creates the Simpsons demo identities in oneofus, Hablo delegate keys, and Hablo contact data.
Run the nerdster step first — it produces the key files that hablotengo consumes.

---

## On the emulator

### 1. Start emulators empty

```
cd ~/src/github/nerdster14   && bin/start_emulator.sh --empty
cd ~/src/github/oneofusv22   && bin/start_emulator.sh --empty
cd ~/src/github/hablotengo   && bin/start_emulator.sh --empty
```

### 2. Create nerdster demo data

```
cd ~/src/github/nerdster14
bin/createSimpsonsDemoData.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

### 3. Create Hablo contact data

```
cd ~/src/github/hablotengo
bin/createSimpsonsContactData.sh
```

Reads the JSON files above. Pushes Hablo delegate keys to oneofus and writes contact data to hablotengo.

---

## On production

### 1. Create nerdster demo data

```
cd ~/src/github/nerdster14
bin/createSimpsonsDemoData_prod.sh
```

Writes `../simpsonsPublicKeys.json`, `../simpsonsPrivateKeys.json`, `web/common/data/demoData.js`.

### 2. Temporarily disable the demo write guard

In `functions/set_my_contact.js`, comment out the block:
```js
// if (auth.isDemo && process.env.FUNCTIONS_EMULATOR !== 'true') {
//   res.status(403).send('Demo users cannot write in production');
//   return;
// }
```

### 3. Deploy hablotengo functions

```
cd ~/src/github/hablotengo
firebase deploy --only functions:setMyContact,functions:demoSignIn
```

`demoSignIn` needs redeployment because `simpsons_keys.json` is regenerated in step 2.

### 4. Create Hablo contact data

```
cd ~/src/github/hablotengo
bin/createSimpsonsContactData_prod.sh
```

### 5. Re-enable the demo write guard and redeploy

Uncomment the block in `functions/set_my_contact.js` and redeploy:
```
firebase deploy --only functions:setMyContact
```

### 6. Deploy hablotengo web app

```
cd ~/src/github/hablotengo
bin/deploy_web.sh
```

Required because `simpsons_public_keys.dart` (compiled into the web app) contains the new identities.

### 7. Commit and deploy nerdster

Commit `web/common/data/demoData.js` in nerdster14 and deploy the web app.
