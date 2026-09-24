# Diorama Slash Sprite Sheet Campaign

## Mission

Render the complete native slash animation vocabulary from the real Diorama of Descension source asset into one transparent fixed-canvas sprite sheet.

## Source authority

- Nested source project: `assets/legacy/diorama-of-descension/`
- Native scene: `res://scenes/Slash.tscn`
- Native mesh/material/shader/AnimationPlayer are used directly.

## Deliverable

`assets/legacy/diorama-of-descension/generated/slash-sprite-sheet/diorama_slash_full_sheet.png`

The exporter also emits individual PNG frames plus `manifest.json` so the sheet can be procedurally consumed later.

## Hard constraints

- Export every sampled frame from every native slash animation except `RESET`.
- Default sampling rate: 60 FPS.
- Fixed canvas for every frame.
- Transparent RGBA.
- No per-frame crop.
- No auto-centering.
- No recreation of the material.
- No gameplay-video extraction.
- No pruning or hand-picking.

## Run on the phone

From the `diorama-descent` checkout:

```sh
bash tools/campaigns/diorama-slash-sprite-sheet/run.sh
```

Optional controls:

```sh
FPS=60 FRAME_SIZE=768 COLUMNS=8 \
  bash tools/campaigns/diorama-slash-sprite-sheet/run.sh
```

If the Godot executable is not on PATH:

```sh
GODOT_BIN=/path/to/godot \
  bash tools/campaigns/diorama-slash-sprite-sheet/run.sh
```

## Acceptance

The campaign is complete only when the phone-side run prints `SLASH_SHEET_CAMPAIGN_OK` and the sprite sheet exists at the exact deliverable path above.
