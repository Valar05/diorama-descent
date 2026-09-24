#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC="$REPO_ROOT/assets/legacy/diorama-of-descension/generated/slash-camera-keys"
DST="/storage/emulated/0/Download/Diorama-Slash-Keys"

mkdir -p "$DST"

FILES=(
  launcher.png
  slash_diagonal_left.png
  slash_diagonal_right.png
  slash_down.png
  slash_left.png
  slash_right.png
  cross_slash.png
  diorama_slash_camera_keys.png
  manifest.json
  harvest-console.log
)

missing=0
for f in "${FILES[@]}"; do
  if [[ -f "$SRC/$f" ]]; then
    cp -f "$SRC/$f" "$DST/$f"
    echo "COPIED $f"
  elif [[ -f "$DST/$f" ]]; then
    echo "ALREADY_IN_DOWNLOADS $f"
  else
    echo "MISSING $f"
    missing=1
  fi
done

echo
echo "=== DOWNLOADS CONTENTS ==="
ls -lah "$DST"

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "STOP: one or more expected harvest artifacts are absent from both source and Downloads."
  exit 2
fi

echo
echo "DIORAMA_SLASH_KEYS_DELIVERED"
echo "downloads=$DST"
