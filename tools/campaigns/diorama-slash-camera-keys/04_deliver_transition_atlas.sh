#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SRC_DIR="$REPO_ROOT/assets/legacy/diorama-of-descension/generated/slash-sprite-sheet-python"
SRC_ATLAS="$SRC_DIR/diorama_slash_full_sheet.png"
SRC_MANIFEST="$SRC_DIR/manifest.json"

DST_DIR="/storage/emulated/0/Download/Diorama-Slash-Keys"
DST_ATLAS="$DST_DIR/diorama_slash_transition_atlas_full.png"
DST_MANIFEST="$DST_DIR/diorama_slash_transition_atlas_full_manifest.json"

mkdir -p "$DST_DIR"

if [[ ! -s "$SRC_ATLAS" ]]; then
  echo "STOP: large transition atlas missing:"
  echo "$SRC_ATLAS"
  exit 2
fi

cp -f "$SRC_ATLAS" "$DST_ATLAS"
echo "COPIED atlas -> $DST_ATLAS"

if [[ -s "$SRC_MANIFEST" ]]; then
  cp -f "$SRC_MANIFEST" "$DST_MANIFEST"
  echo "COPIED manifest -> $DST_MANIFEST"
fi

if command -v termux-media-scan >/dev/null 2>&1; then
  termux-media-scan "$DST_ATLAS" >/dev/null 2>&1 || true
  [[ -f "$DST_MANIFEST" ]] && termux-media-scan "$DST_MANIFEST" >/dev/null 2>&1 || true
fi

echo
echo "=== DELIVERED ==="
ls -lh "$DST_ATLAS"
[[ -f "$DST_MANIFEST" ]] && ls -lh "$DST_MANIFEST" || true

echo
echo "DIORAMA_TRANSITION_ATLAS_DELIVERED"
echo "atlas=$DST_ATLAS"
