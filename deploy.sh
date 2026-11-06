#!/usr/bin/env bash
# Copy addons from this repo into the WoW Forever AddOns folder.
#   ./deploy.sh              deploy every addon (any top-level folder with a matching <Name>.toc)
#   ./deploy.sh TrainerBook  deploy one
# Then /reload in game (a changed .toc needs a client restart).
set -euo pipefail

ADDONS_DIR="${WOW_ADDONS_DIR:-/mnt/d/Games/World of Warcraft/_forever_/Interface/AddOns}"
cd "$(dirname "$0")"

[[ -d "$ADDONS_DIR" ]] || { echo "AddOns folder not found: $ADDONS_DIR" >&2; exit 1; }

if [[ $# -gt 0 ]]; then
    names=("$@")
else
    names=()
    for d in */; do
        d="${d%/}"
        [[ -f "$d/$d.toc" ]] && names+=("$d")
    done
fi

for name in "${names[@]}"; do
    [[ -f "$name/$name.toc" ]] || { echo "skip $name: no $name/$name.toc" >&2; continue; }
    # --delete keeps the game copy identical; tools/ and caches never ship.
    rsync -a --delete --delete-excluded --exclude tools/ --exclude .cache/ --exclude '*.md' "$name/" "$ADDONS_DIR/$name/"
    echo "deployed $name -> $ADDONS_DIR/$name"
done
