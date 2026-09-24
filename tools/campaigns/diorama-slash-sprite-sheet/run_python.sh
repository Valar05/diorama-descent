#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEGACY_PROJECT="$REPO_ROOT/assets/legacy/diorama-of-descension"
PY_SCRIPT="$LEGACY_PROJECT/tools/synthesize_slash_sprite_sheet.py"

FPS="${FPS:-60}"
FRAME_SIZE="${FRAME_SIZE:-768}"
COLUMNS="${COLUMNS:-8}"

OUT_DIR="$LEGACY_PROJECT/generated/slash-sprite-sheet-python"
CONSOLE_LOG="$OUT_DIR/console.log"
SHEET="$OUT_DIR/diorama_slash_full_sheet.png"
MANIFEST="$OUT_DIR/manifest.json"

mkdir -p "$OUT_DIR"
: > "$CONSOLE_LOG"

copy_console() {
  if command -v termux-clipboard-set >/dev/null 2>&1 && [[ -f "$CONSOLE_LOG" ]]; then
    termux-clipboard-set < "$CONSOLE_LOG" >/dev/null 2>&1 || true
  fi
}
trap copy_console EXIT INT TERM

{
  echo "CAMPAIGN=diorama-slash-sprite-sheet-python"
  echo "repo=$REPO_ROOT"
  echo "legacy=$LEGACY_PROJECT"
  echo "fps=$FPS"
  echo "frame_size=$FRAME_SIZE"
  echo "columns=$COLUMNS"
  echo

  if [[ ! -f "$PY_SCRIPT" ]]; then
    echo "STOP: missing synthesizer: $PY_SCRIPT"
    exit 2
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "STOP: python3 not found"
    exit 3
  fi

  python3 - <<'PY'
try:
    import PIL
    print("PILLOW_OK=" + getattr(PIL, "__version__", "unknown"))
except Exception as exc:
    print("STOP: Pillow import failed:", exc)
    raise SystemExit(4)
PY
  STATUS=$?
  [[ "$STATUS" -eq 0 ]] || exit "$STATUS"

  python3 "$PY_SCRIPT" \
    --fps="$FPS" \
    --frame-size="$FRAME_SIZE" \
    --columns="$COLUMNS"
  STATUS=$?

  echo
  echo "python_status=$STATUS"

  if [[ "$STATUS" -ne 0 ]]; then
    echo "STOP: slash synthesizer failed"
    exit "$STATUS"
  fi

  if [[ ! -s "$SHEET" ]]; then
    echo "STOP: sprite sheet missing: $SHEET"
    exit 5
  fi

  if [[ ! -s "$MANIFEST" ]]; then
    echo "STOP: manifest missing: $MANIFEST"
    exit 6
  fi

  echo "SLASH_SHEET_CAMPAIGN_OK"
  echo "sheet=$SHEET"
  echo "manifest=$MANIFEST"
  echo "console=$CONSOLE_LOG"
} 2>&1 | tee -a "$CONSOLE_LOG"

PIPE_STATUS=${PIPESTATUS[0]}
copy_console
exit "$PIPE_STATUS"
