#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEGACY_PROJECT="$REPO_ROOT/assets/legacy/diorama-of-descension"
OUT_DIR="$LEGACY_PROJECT/generated/slash-camera-keys"
LOG="$OUT_DIR/harvest-console.log"
SHEET="$OUT_DIR/diorama_slash_camera_keys.png"
MANIFEST="$OUT_DIR/manifest.json"
REAL_GODOT="${GODOT_REAL:-/data/data/com.termux/files/home/godot-4.5-linux-arm64/Godot_v4.5-stable_linux.arm64}"

mkdir -p "$OUT_DIR"
: > "$LOG"

copy_log() {
  if command -v termux-clipboard-set >/dev/null 2>&1 && [[ -f "$LOG" ]]; then
    termux-clipboard-set < "$LOG" >/dev/null 2>&1 || true
  fi
}
trap copy_log EXIT INT TERM

{
  echo "CAMPAIGN=diorama-slash-camera-keys"
  echo "STEP=02_harvest"
  echo "repo=$REPO_ROOT"
  echo "legacy=$LEGACY_PROJECT"
  echo "sheet=$SHEET"
  echo

  if [[ ! -f "$REAL_GODOT" ]]; then
    echo "STOP: real Godot binary missing: $REAL_GODOT"
    exit 2
  fi

  if [[ ! -f "$LEGACY_PROJECT/tools/export_slash_camera_keys.gd" ]]; then
    echo "STOP: harvest exporter missing"
    exit 3
  fi

  proot-distro login debian \
    --shared-tmp \
    --work-dir "$LEGACY_PROJECT" \
    --env GODOT_SILENCE_ROOT_WARNING=1 \
    --env REAL_GODOT="$REAL_GODOT" \
    --env LEGACY_PROJECT="$LEGACY_PROJECT" \
    -- /bin/bash -lc '
      set -euo pipefail

      for cmd in Xvfb glxinfo; do
        command -v "$cmd" >/dev/null 2>&1 || {
          echo "STOP: $cmd missing. Canary bootstrap did not persist."
          exit 10
        }
      done

      export DISPLAY=:99
      export LIBGL_ALWAYS_SOFTWARE=1
      export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
      export XDG_RUNTIME_DIR=/tmp/xdg-runtime-diorama
      mkdir -p "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"

      rm -f /tmp/.X99-lock
      Xvfb :99 -screen 0 1024x1024x24 -nolisten tcp >/tmp/diorama-xvfb-harvest.log 2>&1 &
      XVFB_PID=$!
      cleanup() { kill "$XVFB_PID" >/dev/null 2>&1 || true; }
      trap cleanup EXIT INT TERM

      sleep 1
      echo "=== SOFTWARE GL ==="
      glxinfo -B | sed -n "1,24p" || true
      echo "=== GODOT HARVEST ==="

      "$REAL_GODOT" \
        --display-driver x11 \
        --rendering-method gl_compatibility \
        --path "$LEGACY_PROJECT" \
        --script res://tools/export_slash_camera_keys.gd
    '
  STATUS=$?

  echo
  echo "harvest_status=$STATUS"

  if [[ "$STATUS" -ne 0 ]]; then
    echo "STOP: camera-key harvest failed"
    exit "$STATUS"
  fi

  if [[ ! -s "$SHEET" ]]; then
    echo "STOP: sheet missing: $SHEET"
    exit 20
  fi

  if [[ ! -s "$MANIFEST" ]]; then
    echo "STOP: manifest missing: $MANIFEST"
    exit 21
  fi

  echo "DIORAMA_CAMERA_KEY_HARVEST_OK"
  echo "sheet=$SHEET"
  echo "manifest=$MANIFEST"
  echo "console=$LOG"
} 2>&1 | tee -a "$LOG"

STATUS=${PIPESTATUS[0]}
copy_log
exit "$STATUS"
