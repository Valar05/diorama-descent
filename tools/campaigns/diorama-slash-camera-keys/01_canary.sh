#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEGACY_PROJECT="$REPO_ROOT/assets/legacy/diorama-of-descension"
OUT_DIR="$LEGACY_PROJECT/generated/slash-camera-keys"
LOG="$OUT_DIR/canary-console.log"
PNG="$OUT_DIR/canary_slash_left.png"
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
  echo "STEP=01_canary"
  echo "repo=$REPO_ROOT"
  echo "legacy=$LEGACY_PROJECT"
  echo "png=$PNG"
  echo

  if [[ ! -f "$REAL_GODOT" ]]; then
    echo "STOP: real Godot binary missing: $REAL_GODOT"
    exit 2
  fi

  if [[ ! -f "$LEGACY_PROJECT/tools/export_slash_camera_key_canary.gd" ]]; then
    echo "STOP: canary exporter missing"
    exit 3
  fi

  echo "Launching Debian Xvfb + llvmpipe canary..."

  proot-distro login debian \
    --shared-tmp \
    --work-dir "$LEGACY_PROJECT" \
    --env GODOT_SILENCE_ROOT_WARNING=1 \
    --env REAL_GODOT="$REAL_GODOT" \
    --env LEGACY_PROJECT="$LEGACY_PROJECT" \
    -- /bin/bash -lc '
      set -euo pipefail

      need_install=0
      command -v Xvfb >/dev/null 2>&1 || need_install=1
      command -v glxinfo >/dev/null 2>&1 || need_install=1

      if [[ "$need_install" -eq 1 ]]; then
        echo "BOOTSTRAP: installing Xvfb + Mesa software GL in Debian"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y xvfb mesa-utils libgl1-mesa-dri libglx-mesa0
      fi

      export DISPLAY=:99
      export LIBGL_ALWAYS_SOFTWARE=1
      export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
      export XDG_RUNTIME_DIR=/tmp/xdg-runtime-diorama
      mkdir -p "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"

      rm -f /tmp/.X99-lock
      Xvfb :99 -screen 0 1024x1024x24 -nolisten tcp >/tmp/diorama-xvfb.log 2>&1 &
      XVFB_PID=$!
      cleanup() {
        kill "$XVFB_PID" >/dev/null 2>&1 || true
      }
      trap cleanup EXIT INT TERM

      sleep 1
      echo "=== SOFTWARE GL ==="
      glxinfo -B || true
      echo "=== GODOT CANARY ==="

      "$REAL_GODOT" \
        --display-driver x11 \
        --rendering-method gl_compatibility \
        --path "$LEGACY_PROJECT" \
        --script res://tools/export_slash_camera_key_canary.gd
    '
  STATUS=$?

  echo
  echo "canary_status=$STATUS"

  if [[ "$STATUS" -ne 0 ]]; then
    echo "STOP: camera-key canary failed"
    exit "$STATUS"
  fi

  if [[ ! -s "$PNG" ]]; then
    echo "STOP: canary reported success but PNG is missing: $PNG"
    exit 8
  fi

  echo "DIORAMA_CAMERA_KEY_CANARY_OK"
  echo "png=$PNG"
  echo "console=$LOG"
} 2>&1 | tee -a "$LOG"

STATUS=${PIPESTATUS[0]}
copy_log
exit "$STATUS"
