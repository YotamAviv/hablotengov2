#!/usr/bin/env python3
"""Reads a log file (from createSimpsonsContactData.sh), parses HABLO_DELEGATE lines,
and writes {name}-hablo0 entries to simpsonsPrivateKeys.json."""
import json, os, re, sys

if len(sys.argv) != 2:
    print(f'Usage: {sys.argv[0]} <log_file>', file=sys.stderr)
    sys.exit(1)

script_dir = os.path.dirname(os.path.abspath(__file__))
keys_path = os.path.join(script_dir, '..', '..', 'simpsonsPrivateKeys.json')

with open(keys_path) as f:
    all_keys = json.load(f)

with open(sys.argv[1]) as f:
    for line in f:
        m = re.match(r'HABLO_DELEGATE:(\w+):(.+)', line.strip())
        if m:
            name, key_json = m.group(1), m.group(2)
            all_keys[f'{name}-hablo0'] = {'keyPair': json.loads(key_json)}
            print(f'Saved: {name}-hablo0')

with open(keys_path, 'w') as f:
    json.dump(all_keys, f, indent=2)
    f.write('\n')
