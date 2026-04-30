#!/usr/bin/env python3
"""Reads ../simpsonsPublicKeys.json and writes functions/simpsons_keys.json.
Only includes the characters who have Hablo contact data."""
import json, os

DEMO_CHARACTERS = ['lisa', 'bart', 'homer', 'homer2', 'marge', 'maggie', 'milhouse', 'luann', 'ralph', 'nelson', 'lenny', 'carl', 'burns', 'smithers', 'krusty', 'sideshow', 'mel', 'seymore', 'amanda']

script_dir = os.path.dirname(os.path.abspath(__file__))
keys_path = os.path.join(script_dir, '..', '..', 'simpsonsPublicKeys.json')
out_path = os.path.join(script_dir, '..', 'functions', 'simpsons_keys.json')

with open(keys_path) as f:
    all_keys = json.load(f)

keys = {name: all_keys[name] for name in DEMO_CHARACTERS}

with open(out_path, 'w') as f:
    json.dump(keys, f, indent=2)
    f.write('\n')

print(f'Written: {out_path}')
