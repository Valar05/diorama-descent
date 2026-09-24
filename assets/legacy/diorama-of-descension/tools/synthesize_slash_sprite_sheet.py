#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import re
import sys
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    from PIL import Image
except Exception as exc:
    print(f"STOP: Pillow is required: {exc}", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / "scenes" / "Slash.tscn"
TEXTURE = ROOT / "sprites" / "SlashTex.png"
GRADIENT = ROOT / "scenes" / "SlashGradient.tres"
OUT = ROOT / "generated" / "slash-sprite-sheet-python"
FRAMES = OUT / "frames"
SHEET = OUT / "diorama_slash_full_sheet.png"
MANIFEST = OUT / "manifest.json"

FPS = 60
FRAME_SIZE = 768
COLUMNS = 8


@dataclass
class Track:
    path: str
    times: list[float]
    values: list[Any]


@dataclass
class AnimationDef:
    name: str
    length: float
    tracks: dict[str, Track]


def split_top_level(text: str) -> list[str]:
    out: list[str] = []
    buf: list[str] = []
    depth = 0
    in_string = False
    escaped = False
    for ch in text:
        if in_string:
            buf.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            buf.append(ch)
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    if buf:
        out.append("".join(buf).strip())
    return [x for x in out if x]


def parse_scalar_or_vector(token: str) -> Any:
    token = token.strip()
    if token.startswith("Vector2(") and token.endswith(")"):
        a, b = split_top_level(token[8:-1])
        return (float(a), float(b))
    if token.startswith("Vector3(") and token.endswith(")"):
        vals = split_top_level(token[8:-1])
        return tuple(float(v) for v in vals)
    if token in ("true", "false"):
        return token == "true"
    try:
        return float(token)
    except ValueError:
        return token


def parse_float_array(expr: str) -> list[float]:
    m = re.search(r"PackedFloat32Array\((.*?)\)", expr, re.S)
    if not m:
        return []
    inner = m.group(1).strip()
    if not inner:
        return []
    return [float(x.strip()) for x in split_top_level(inner)]


def parse_values(expr: str) -> list[Any]:
    m = re.search(r'"values"\s*:\s*\[(.*?)\]\s*}', expr, re.S)
    if not m:
        return []
    inner = m.group(1).strip()
    if not inner:
        return []
    return [parse_scalar_or_vector(x) for x in split_top_level(inner)]


def read_balanced_brace_block(lines: list[str], start_index: int) -> tuple[str, int]:
    buf: list[str] = []
    depth = 0
    started = False
    i = start_index
    while i < len(lines):
        line = lines[i]
        buf.append(line)
        for ch in line:
            if ch == "{":
                depth += 1
                started = True
            elif ch == "}":
                depth -= 1
        if started and depth == 0:
            return "\n".join(buf), i
        i += 1
    raise ValueError("unterminated brace block")


def parse_animation_blocks(scene_text: str) -> dict[str, tuple[float, dict[str, Track]]]:
    lines = scene_text.splitlines()
    blocks: dict[str, tuple[float, dict[str, Track]]] = {}
    i = 0
    current_id: str | None = None
    current_lines: list[str] = []

    def finish_block() -> None:
        nonlocal current_id, current_lines
        if current_id is None:
            return
        text = "\n".join(current_lines)
        length_m = re.search(r"^length\s*=\s*([0-9.eE+-]+)", text, re.M)
        length = float(length_m.group(1)) if length_m else 0.001

        tracks: dict[str, Track] = {}
        path_matches = list(re.finditer(r'^tracks/(\d+)/path\s*=\s*NodePath\("([^"]+)"\)', text, re.M))
        for pm in path_matches:
            idx = pm.group(1)
            path = pm.group(2)
            key_m = re.search(rf'^tracks/{idx}/keys\s*=\s*\{{', text, re.M)
            if not key_m:
                continue
            start = key_m.start()
            sub = text[start:]
            brace_start = sub.find("{")
            depth = 0
            end = None
            for off, ch in enumerate(sub[brace_start:], start=brace_start):
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end = off + 1
                        break
            if end is None:
                continue
            expr = sub[:end]
            times = parse_float_array(expr)
            values = parse_values(expr)
            if times and values and len(times) == len(values):
                tracks[path] = Track(path=path, times=times, values=values)

        blocks[current_id] = (length, tracks)
        current_id = None
        current_lines = []

    for line in lines:
        m = re.match(r'\[sub_resource type="Animation" id="([^"]+)"\]', line)
        if m:
            finish_block()
            current_id = m.group(1)
            current_lines = [line]
        elif current_id is not None:
            if line.startswith("[sub_resource ") or line.startswith("[node ") or line.startswith("[ext_resource "):
                finish_block()
                m2 = re.match(r'\[sub_resource type="Animation" id="([^"]+)"\]', line)
                if m2:
                    current_id = m2.group(1)
                    current_lines = [line]
            else:
                current_lines.append(line)
    finish_block()
    return blocks


def parse_animation_library(scene_text: str) -> dict[str, str]:
    m = re.search(r'\[sub_resource type="AnimationLibrary" id="[^"]+"\](.*?)(?=\n\[)', scene_text, re.S)
    if not m:
        raise ValueError("AnimationLibrary not found")
    block = m.group(1)
    data_m = re.search(r'_data\s*=\s*\{(.*?)\}', block, re.S)
    if not data_m:
        raise ValueError("AnimationLibrary _data not found")
    out: dict[str, str] = {}
    for name, sub_id in re.findall(r'&"([^"]+)"\s*:\s*SubResource\("([^"]+)"\)', data_m.group(1)):
        out[name] = sub_id
    return out


def parse_gradient(path: Path) -> tuple[list[float], list[tuple[float, float, float, float]]]:
    text = path.read_text()
    om = re.search(r'offsets\s*=\s*PackedFloat32Array\((.*?)\)', text, re.S)
    cm = re.search(r'colors\s*=\s*PackedColorArray\((.*?)\)', text, re.S)
    if not om or not cm:
        raise ValueError("gradient data missing")
    offsets = [float(x) for x in split_top_level(om.group(1))]
    nums = [float(x) for x in split_top_level(cm.group(1))]
    if len(nums) % 4:
        raise ValueError("gradient colors are not RGBA quads")
    colors = [tuple(nums[i:i+4]) for i in range(0, len(nums), 4)]
    if len(offsets) != len(colors):
        raise ValueError("gradient offsets/colors length mismatch")
    return offsets, colors


def lerp(a: Any, b: Any, t: float) -> Any:
    if isinstance(a, tuple) and isinstance(b, tuple):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    return float(a) + (float(b) - float(a)) * t


def sample_track(track: Track | None, t: float, default: Any) -> Any:
    if track is None or not track.times:
        return default
    if t <= track.times[0]:
        return track.values[0]
    if t >= track.times[-1]:
        return track.values[-1]
    for i in range(len(track.times) - 1):
        t0, t1 = track.times[i], track.times[i + 1]
        if t0 <= t <= t1:
            if t1 <= t0:
                return track.values[i + 1]
            alpha = (t - t0) / (t1 - t0)
            return lerp(track.values[i], track.values[i + 1], alpha)
    return track.values[-1]


def sample_gradient(x: float, offsets: list[float], colors: list[tuple[float, float, float, float]]) -> tuple[int, int, int, int]:
    x = max(0.0, min(1.0, x))
    if x <= offsets[0]:
        c = colors[0]
    elif x >= offsets[-1]:
        c = colors[-1]
    else:
        c = colors[-1]
        for i in range(len(offsets) - 1):
            if offsets[i] <= x <= offsets[i + 1]:
                span = offsets[i + 1] - offsets[i]
                a = 0.0 if span <= 0 else (x - offsets[i]) / span
                c = tuple(colors[i][j] + (colors[i + 1][j] - colors[i][j]) * a for j in range(4))
                break
    return tuple(max(0, min(255, int(round(v * 255.0)))) for v in c)


def gradient_remap(img: Image.Image, offsets: list[float], colors: list[tuple[float, float, float, float]]) -> Image.Image:
    src = img.convert("RGBA")
    pix = src.load()
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    dst = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = pix[x, y]
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            gr, gg, gb, ga = sample_gradient(lum, offsets, colors)
            alpha = int(round((r / 255.0) * (ga / 255.0) * 255.0))
            dst[x, y] = (gr, gg, gb, min(a, alpha))
    return out


def apply_progress_collapse(img: Image.Image, progress: float, collapse: float, collapse_center: float = 0.5) -> Image.Image:
    src = img.convert("RGBA")
    w, h = src.size
    progress = max(0.0, min(1.0, progress))
    collapse = max(0.0, min(1.0, collapse))

    visible_w = max(1, int(round(w * progress)))
    if progress <= 0.000001:
        return Image.new("RGBA", src.size, (0, 0, 0, 0))

    # Shader semantics approximate: texture slides in along X as progress rises.
    cropped = src.crop((0, 0, visible_w, h))
    stage = Image.new("RGBA", src.size, (0, 0, 0, 0))
    stage.alpha_composite(cropped, (w - visible_w, 0))

    if collapse <= 0.000001:
        return stage
    if collapse >= 0.999999:
        return Image.new("RGBA", src.size, (0, 0, 0, 0))

    band_h = max(1, int(round(h * (1.0 - collapse))))
    center_y = int(round(h * collapse_center))
    y0 = max(0, center_y - band_h // 2)
    y1 = min(h, y0 + band_h)
    masked = Image.new("RGBA", src.size, (0, 0, 0, 0))
    masked.alpha_composite(stage.crop((0, y0, w, y1)), (0, y0))
    return masked


def transform_to_canvas(img: Image.Image, scale: tuple[float, float], rotation_radians: float, position: tuple[float, float]) -> Image.Image:
    sx, sy = scale
    sx = sx if abs(sx) > 1e-6 else 1e-6
    sy = sy if abs(sy) > 1e-6 else 1e-6

    flip_x = sx < 0
    flip_y = sy < 0
    sx, sy = abs(sx), abs(sy)

    work = img
    if flip_x:
        work = work.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if flip_y:
        work = work.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

    nw = max(1, int(round(work.width * sx)))
    nh = max(1, int(round(work.height * sy)))
    work = work.resize((nw, nh), Image.Resampling.BICUBIC)
    degrees = -math.degrees(rotation_radians)
    work = work.rotate(degrees, expand=True, resample=Image.Resampling.BICUBIC)

    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    cx = FRAME_SIZE // 2 + int(round(position[0] * 0.15))
    cy = FRAME_SIZE // 2 + int(round(position[1] * 0.15))
    x = cx - work.width // 2
    y = cy - work.height // 2
    canvas.alpha_composite(work, (x, y))
    return canvas


def parse_args(argv: list[str]) -> None:
    global FPS, FRAME_SIZE, COLUMNS
    for arg in argv:
        if arg.startswith("--fps="):
            FPS = max(1, int(arg.split("=", 1)[1]))
        elif arg.startswith("--frame-size="):
            FRAME_SIZE = max(64, int(arg.split("=", 1)[1]))
        elif arg.startswith("--columns="):
            COLUMNS = max(1, int(arg.split("=", 1)[1]))


def main() -> int:
    parse_args(sys.argv[1:])
    print("SLASH_SYNTH_START")
    print(f"scene={SCENE}")
    print(f"texture={TEXTURE}")
    print(f"gradient={GRADIENT}")

    for required in (SCENE, TEXTURE, GRADIENT):
        if not required.is_file():
            print(f"STOP: missing source file: {required}", file=sys.stderr)
            return 2

    OUT.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)

    scene_text = SCENE.read_text()
    blocks = parse_animation_blocks(scene_text)
    library = parse_animation_library(scene_text)
    offsets, colors = parse_gradient(GRADIENT)

    native = Image.open(TEXTURE).convert("RGBA")
    native = gradient_remap(native, offsets, colors)

    animations: list[AnimationDef] = []
    for name, sub_id in sorted(library.items()):
        if name == "RESET":
            continue
        if sub_id not in blocks:
            print(f"STOP: animation block missing for {name}: {sub_id}", file=sys.stderr)
            return 3
        length, tracks = blocks[sub_id]
        animations.append(AnimationDef(name=name, length=length, tracks=tracks))

    if not animations:
        print("STOP: no animations discovered", file=sys.stderr)
        return 4

    frame_records: list[dict[str, Any]] = []
    rendered: list[Image.Image] = []

    for anim in animations:
        count = int(math.floor(anim.length * FPS)) + 1
        print(f"animation={anim.name} length={anim.length:.4f}s frames={count}")
        for i in range(count):
            t = min(i / FPS, max(anim.length - 1e-6, 0.0))

            progress = float(sample_track(
                anim.tracks.get("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/progress"),
                t, 1.0
            ))
            collapse = float(sample_track(
                anim.tracks.get("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/collapse"),
                t, 0.0
            ))
            scale = sample_track(anim.tracks.get("TextureRect:scale"), t, (1.0, 1.0))
            position = sample_track(anim.tracks.get("TextureRect:position"), t, (0.0, 0.0))
            rotation = float(sample_track(anim.tracks.get("TextureRect:rotation"), t, 0.0))

            print(
                f"render {anim.name} frame {i:04d} t={t:.4f} "
                f"progress={progress:.3f} collapse={collapse:.3f}"
            )

            frame = apply_progress_collapse(native, progress, collapse)
            frame = transform_to_canvas(frame, scale, rotation, position)

            safe = re.sub(r"[^a-z0-9]+", "_", anim.name.lower()).strip("_")
            fname = f"{safe}_{i:04d}.png"
            fpath = FRAMES / fname
            frame.save(fpath)

            frame_records.append({
                "index": len(frame_records),
                "animation": anim.name,
                "local_index": i,
                "time_seconds": round(t, 6),
                "progress": round(progress, 6),
                "collapse": round(collapse, 6),
                "scale": [round(float(scale[0]), 6), round(float(scale[1]), 6)],
                "position": [round(float(position[0]), 6), round(float(position[1]), 6)],
                "rotation_radians": round(rotation, 6),
                "file": f"frames/{fname}",
            })
            rendered.append(frame)

    rows = int(math.ceil(len(rendered) / COLUMNS))
    sheet = Image.new("RGBA", (COLUMNS * FRAME_SIZE, rows * FRAME_SIZE), (0, 0, 0, 0))
    for idx, frame in enumerate(rendered):
        x = (idx % COLUMNS) * FRAME_SIZE
        y = (idx // COLUMNS) * FRAME_SIZE
        sheet.alpha_composite(frame, (x, y))
        frame_records[idx]["sheet_col"] = idx % COLUMNS
        frame_records[idx]["sheet_row"] = idx // COLUMNS

    sheet.save(SHEET)

    manifest = {
        "schema": "diorama-slash-python-synth-v1",
        "source_scene": str(SCENE.relative_to(ROOT)),
        "source_texture": str(TEXTURE.relative_to(ROOT)),
        "source_gradient": str(GRADIENT.relative_to(ROOT)),
        "fps": FPS,
        "frame_size": FRAME_SIZE,
        "columns": COLUMNS,
        "rows": rows,
        "frame_count": len(frame_records),
        "animations": [a.name for a in animations],
        "sheet": SHEET.name,
        "frames": frame_records,
        "contract": {
            "no_godot_renderer_readback": True,
            "fixed_canvas": True,
            "transparent_rgba": True,
            "no_per_frame_crop": True,
            "full_native_animation_sampling": True,
            "source_animation_parameters_used": [
                "progress",
                "collapse",
                "TextureRect:scale",
                "TextureRect:position",
                "TextureRect:rotation",
            ],
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")

    print("SLASH_SYNTH_OK")
    print(f"sheet={SHEET}")
    print(f"manifest={MANIFEST}")
    print(f"frames={len(frame_records)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        raise SystemExit(99)
