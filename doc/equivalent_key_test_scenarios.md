# Equivalent Key Test Scenarios — Homer & Homer2

Each scenario starts with a fresh state:
```
./bin/stop_emulator.sh
./bin/start_emulator.sh
./bin/createSimpsonsContactData.sh
```

---

## Scenario A: Homer2 dismisses homer (old key)

1. Sign in as homer2
2. Equivalent popup appears for homer
3. Dismiss
4. Homer2 is not visible (no contact card stored)
5. Go to Settings → enable "Show empty cards" and "Show hidden cards"
6. Homer2 is now visible as moniker "Holmes"
7. Reload — same result
8. Popup does not reappear on re-sign-in

---

## Scenario B: Homer2 merges & disables homer (old key)

1. Sign in as homer2
2. Equivalent popup appears for homer
3. Merge & disable
4. Contacts list reloads: homer2 card has homer's entries merged in, homer does NOT appear as separate contact
5. Popup does not reappear on re-sign-in

---

## Scenario C: Homer (old key) signs in — account not disabled

1. Sign in as homer
2. No "Account disabled" alert
3. Contacts list loads normally; homer2 appears as a separate contact (from homer's PoV, homer2 is a distinct trusted identity)
4. No equivalent popup

---

## Scenario D: Homer (old key) signs in — account disabled — chooses Enable

1. (Setup) Homer2 disables homer via API
2. Sign in as homer
3. "Account disabled" alert shows homer2 as disabler
4. Click Enable
5. Alert gone, contacts list loads normally

---

## Scenario E: Homer (old key) signs in — account disabled — chooses Sign out

1. (Setup) Homer2 disables homer via API
2. Sign in as homer
3. "Account disabled" alert shows homer2 as disabler
4. Click Sign out
5. Returns to sign-in screen
