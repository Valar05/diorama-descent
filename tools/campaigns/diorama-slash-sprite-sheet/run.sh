#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEGACY_PROJECT="$REPO_ROOT/assets/legacy/diorama-of-descension"

FPS="${FPS:-60}"
FRAME_SIZE="${FRAME_SIZE:-768}"
COLUMNS="${COLUMNS:-8}"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="$(command -v godot4)"
else
  echo "STOP: Godot CLI not found. Set GODOT_BIN to the Godot executable." >&2
  exit 2
fi

if [[ ! -f "$LEGACY_PROJECT/project.godot" ]]; then
  echo "STOP: legacy Diorama project missing: $LEGACY_PROJECT" >&2
  exit 3
fi

cd "$LEGACY_PROJECT"

"$GODOT" \
  --path "$LEGACY_PROJECT" \
  --script res://tools/export_slash_sprite_sheet.gd \
  -- \
  --fps="$FPS" \
  --frame-size="$FRAME_SIZE" \
  --columns="$COLUMNS"

OUT="$LEGACY_PROJECT/generated/slash-sprite-sheet/diorama_slash_full_sheet.png"
MANIFEST="$LEGACY_PROJECT/generated/slash-sprite-sheet/manifest.json"

[[ -s "$OUT" ]] || { echo "STOP: sprite sheet was not produced: $OUT" >&2; exit 4; }
[[ -s "$MANIFEST" ]] || { echo "STOP: manifest was not produced: $MANIFEST" >&2; exit 5; }

echo "SLASH_SHEET_CAMPAIGN_OK"
echo "sheet=$OUT"
echo "manifest=$MANIFEST"
