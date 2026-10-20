#!/usr/bin/env python3
"""Build a deterministic, offline, single-file ComputerCraft installer."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]

def lua_string(value):
    # Long strings preserve all bytes; increase delimiter depth if needed.
    text = value.decode('utf-8') if isinstance(value, bytes) else value
    level = 0
    while ']' + '=' * level + ']' in text:
        level += 1
    return '[' + '=' * level + '[\n' + text + ']' + '=' * level + ']'

def main():
    paths = [ROOT / name for name in ('boot.lua', 'uninstall.lua', 'chatplus.lua')]
    for name in ('system', 'apps', 'examples', 'sites'):
        paths += [p for p in (ROOT / name).rglob('*') if p.is_file()]
    files = {}
    for path in sorted(paths):
        # Normalize CRLF for Lua long strings (Lua normalizes line endings).
        data = path.read_bytes().replace(b'\r\n', b'\n').replace(b'\r', b'\n')
        files[path.relative_to(ROOT).as_posix()] = (data, hashlib.sha256(data).hexdigest())
    manifest = 'return {version="1.0.0", files={\n'
    bundle = '-- CCSacabam 1.0.0: standalone offline installer\nlocal package={version="1.0.0",files={\n'
    for name, (data, sha) in files.items():
        manifest += f'  [{json.dumps(name)}]={json.dumps(sha)},\n'
        bundle += f'  [{json.dumps(name)}]={{sha256={json.dumps(sha)},data={lua_string(data)}}},\n'
    manifest += '}}\n'
    bundle += '}}\nlocal installer=(function()\n' + (ROOT/'tools/installer.lua').read_text() + '\nend)()\nreturn installer.run(package,{...})\n'
    (ROOT/'manifest.lua').write_text(manifest)
    dist=ROOT/'dist'; dist.mkdir(exist_ok=True)
    destination=dist/'ccsacabam-installer.lua'; destination.write_text(bundle)
    (dist/'SHA256SUMS').write_text(hashlib.sha256(destination.read_bytes()).hexdigest()+'  ccsacabam-installer.lua\n')
    print(f'Built {destination} ({destination.stat().st_size:,} bytes, {len(files)} files)')

if __name__ == '__main__':
    main()
