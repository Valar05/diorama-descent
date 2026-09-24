# Diorama Slash Camera Keys Campaign

## Mission

Extract one fully-open rendered keyframe from each authored Diorama slash view while preserving the native 3D slash mesh, animation transform, scene Camera3D transform/FOV, material/shader, and perspective projection.

This campaign does **not** export temporal animation frames. The final artifact will be a compact sheet of distinct native slash views, one peak key per authored slash animation/scene.

## Authority

- Source project: `assets/legacy/diorama-of-descension/`
- Primary scene: `res://scenes/Slash.tscn`
- Cross scene: `res://scenes/CrossSlash.tscn`
- Camera3D projection is part of the source truth.
- Peak state is the fully-open slash: `progress = 1`, `collapse = 0`.

## Campaign rule

The first user-facing script is a canary. It must prove a real non-dummy renderer on the phone before the full harvest is authored.

## Step 01: canary

Run:

```sh
bash tools/campaigns/diorama-slash-camera-keys/01_canary.sh
```

The script enters the existing Debian PRoot, installs Xvfb/Mesa software GL if missing, starts a virtual X11 display, forces llvmpipe, launches the real Godot binary with the compatibility renderer, renders `SlashLeft` through its native Camera3D, and saves:

```text
assets/legacy/diorama-of-descension/generated/slash-camera-keys/canary_slash_left.png
```

Console output is always saved and copied to the Android clipboard:

```text
assets/legacy/diorama-of-descension/generated/slash-camera-keys/canary-console.log
```

## Canary acceptance

Completion requires all of:

- real X11 display under Xvfb;
- Mesa software renderer available;
- Godot does not use dummy texture storage;
- native Camera3D reports its FOV/transform;
- rendered image has non-empty pixel bounds;
- `CAMERA_KEY_CANARY_OK`;
- `DIORAMA_CAMERA_KEY_CANARY_OK`;
- canary PNG exists.

Do not proceed to the seven-key harvest if the canary fails.
