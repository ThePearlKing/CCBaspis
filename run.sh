#!/usr/bin/env bash
set -euo pipefail
ccsacabam_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ccsacabam_kind=advanced
case "${1:-}" in
  --basic) ccsacabam_kind=basic ;;
  --advanced|'') ;;
  *) echo 'Usage: ./run.sh [--basic|--advanced]' >&2; exit 2 ;;
esac
ccsacabam_data=${CCSACABAM_DATA_DIR:-"$ccsacabam_root/.craftos/$ccsacabam_kind"}
command -v craftos >/dev/null || { echo 'Install CraftOS-PC first (craftos was not found).' >&2; exit 1; }
python3 - "$ccsacabam_data" "$ccsacabam_kind" <<'PY'
from pathlib import Path
import json, sys
directory = Path(sys.argv[1])
(directory / 'config').mkdir(parents=True, exist_ok=True)
for name, config in {
    'global.json': {'checkUpdates': False, 'standardsMode': True},
    '0.json': {'isColor': sys.argv[2] != 'basic'},
}.items():
    path = directory / 'config' / name
    if not path.exists():
        path.write_text(json.dumps(config))
PY
ccsacabam_args=(--gui -d "$ccsacabam_data" --mount-ro "/package=$ccsacabam_root")
if [[ ! -f "$ccsacabam_data/computer/0/ccsacabam/.ccsacabam" ]]; then
  ccsacabam_args+=(--exec 'shell.run("/package/dist/ccsacabam-installer.lua"); if fs.exists("/ccsacabam/.ccsacabam") then shell.run("/ccsacabam/boot.lua") end')
fi
export SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy}
exec craftos "${ccsacabam_args[@]}"
