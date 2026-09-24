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

OUT_DIR="$LEGACY_PROJECT/generated/slash-sprite-sheet"
FRAMES_DIR="$OUT_DIR/frames"
CONSOLE_LOG="$OUT_DIR/console.log"
OUT="$OUT_DIR/diorama_slash_full_sheet.png"
MANIFEST="$OUT_DIR/manifest.json"

mkdir -p "$FRAMES_DIR"
: > "$CONSOLE_LOG"

cd "$LEGACY_PROJECT"

set +e
"$GODOT" --headless \
  --path "$LEGACY_PROJECT" \
  --script res://tools/export_slash_sprite_sheet.gd \
  -- \
  --fps="$FPS" \
  --frame-size="$FRAME_SIZE" \
  --columns="$COLUMNS" 2>&1 | tee "$CONSOLE_LOG"
STATUS=${PIPESTATUS[0]}
set -e

if [[ "$STATUS" -ne 0 ]]; then
  echo "STOP: Godot exporter failed with status $STATUS"
  echo "console=$CONSOLE_LOG"
  exit "$STATUS"
fi

[[ -s "$OUT" ]] || { echo "STOP: sprite sheet was not produced: $OUT" >&2; echo "console=$CONSOLE_LOG"; exit 4; }
[[ -s "$MANIFEST" ]] || { echo "STOP: manifest was not produced: $MANIFEST" >&2; echo "console=$CONSOLE_LOG"; exit 5; }

echo "SLASH_SHEET_CAMPAIGN_OK"
echo "sheet=$OUT"
echo "manifest=$MANIFEST"
echo "console=$CONSOLE_LOG"
