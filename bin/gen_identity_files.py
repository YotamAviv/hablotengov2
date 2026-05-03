#!/usr/bin/env python3
"""Generates {name}-identity.json files for use with the Android emulator / paste sign-in.
Reads from ../../simpsonsPrivateKeys.json (private keys, not committed).
Output files are git-ignored."""
import json, os

CHARACTERS = {
    'lisa':     'lisa',
    'homer':    'homer',
    'homer2':   'homer',   # Homer's old key, shown as Homer'
    'bart':     'bart',
    'milhouse': 'milhouse',
}

script_dir = os.path.dirname(os.path.abspath(__file__))
keys_path = os.path.join(script_dir, '..', '..', 'simpsonsPrivateKeys.json')
out_dir = os.path.join(script_dir, '..')

with open(keys_path) as f:
    private_keys = json.load(f)

for key_name, display in CHARACTERS.items():
    key = private_keys[key_name]
    out = {'identity': key['keyPair']}
    delegate_key = private_keys.get(f'{key_name}-hablo0')
    if delegate_key:
        out['hablotengo.com'] = delegate_key['keyPair']
    filename = f'{key_name}-identity.json'
    out_path = os.path.join(out_dir, filename)
    with open(out_path, 'w') as f:
        json.dump(out, f, indent=2)
        f.write('\n')
    print(f'Written: {filename}')
