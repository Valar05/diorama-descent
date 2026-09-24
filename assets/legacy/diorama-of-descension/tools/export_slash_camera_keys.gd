extends SceneTree

const OUT_DIR := "res://generated/slash-camera-keys"
const FRAME_SIZE := 760

const JOBS := [
    {"scene": "res://scenes/Slash.tscn", "animation": "Launcher", "slug": "launcher"},
    {"scene": "res://scenes/Slash.tscn", "animation": "SlashDiagonalLeft", "slug": "slash_diagonal_left"},
    {"scene": "res://scenes/Slash.tscn", "animation": "SlashDiagonalRight", "slug": "slash_diagonal_right"},
    {"scene": "res://scenes/Slash.tscn", "animation": "SlashDown", "slug": "slash_down"},
    {"scene": "res://scenes/Slash.tscn", "animation": "SlashLeft", "slug": "slash_left"},
    {"scene": "res://scenes/Slash.tscn", "animation": "SlashRight", "slug": "slash_right"},
    {"scene": "res://scenes/CrossSlash.tscn", "animation": "CrossSlash", "slug": "cross_slash"},
]

func _initialize() -> void:
    call_deferred("_run")

func _strip_empty_animation_tracks(player: AnimationPlayer) -> void:
    for animation_name in player.get_animation_list():
        var animation: Animation = player.get_animation(animation_name)
        if animation == null:
            continue
        for track_index in range(animation.get_track_count() - 1, -1, -1):
            if animation.track_get_key_count(track_index) == 0:
                animation.remove_track(track_index)

func _track_value_at(animation: Animation, path: NodePath, time: float, default_value: float) -> float:
    var track_index: int = animation.find_track(path, Animation.TYPE_VALUE)
    if track_index < 0:
        return default_value
    var keys: int = animation.track_get_key_count(track_index)
    if keys <= 0:
        return default_value

    if time <= animation.track_get_key_time(track_index, 0):
        return float(animation.track_get_key_value(track_index, 0))

    for i in range(keys - 1):
        var t0: float = animation.track_get_key_time(track_index, i)
        var t1: float = animation.track_get_key_time(track_index, i + 1)
        if t0 <= time and time <= t1:
            var v0: float = float(animation.track_get_key_value(track_index, i))
            var v1: float = float(animation.track_get_key_value(track_index, i + 1))
            if is_equal_approx(t0, t1):
                return v1
            return lerpf(v0, v1, (time - t0) / (t1 - t0))

    return float(animation.track_get_key_value(track_index, keys - 1))

func _find_fully_open_time(animation: Animation) -> float:
    var progress_path := NodePath("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/progress")
    var collapse_path := NodePath("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/collapse")

    var progress_track: int = animation.find_track(progress_path, Animation.TYPE_VALUE)
    if progress_track < 0:
        return -1.0

    # Prefer a real authored key where the slash first reaches full extension
    # while remaining uncollapsed.
    for i in range(animation.track_get_key_count(progress_track)):
        var t: float = animation.track_get_key_time(progress_track, i)
        var progress: float = float(animation.track_get_key_value(progress_track, i))
        var collapse: float = _track_value_at(animation, collapse_path, t, 0.0)
        if progress >= 0.999 and collapse <= 0.001:
            return t

    # Fail-safe scan. Never choose a partially collapsed frame.
    var t: float = 0.0
    while t <= animation.length:
        var progress: float = _track_value_at(animation, progress_path, t, 0.0)
        var collapse: float = _track_value_at(animation, collapse_path, t, 0.0)
        if progress >= 0.999 and collapse <= 0.001:
            return t
        t += 1.0 / 240.0

    return -1.0

func _render_job(job: Dictionary) -> Dictionary:
    var scene_path: String = String(job["scene"])
    var animation_name: StringName = StringName(job["animation"])
    var slug: String = String(job["slug"])

    print("")
    print("JOB_START scene=%s animation=%s" % [scene_path, String(animation_name)])

    var packed: PackedScene = load(scene_path)
    if packed == null:
        return {"ok": false, "error": "scene load failed", "job": job}

    var instance := packed.instantiate()
    root.add_child(instance)

    var subviewport: SubViewport = instance.get_node("SubViewport")
    subviewport.transparent_bg = true
    subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    var camera: Camera3D = instance.get_node("SubViewport/WorldEnvironment/Camera3D")
    var player: AnimationPlayer = instance.get_node("AnimationPlayer")
    _strip_empty_animation_tracks(player)

    if not player.has_animation(animation_name):
        instance.queue_free()
        return {"ok": false, "error": "animation missing", "job": job}

    var animation: Animation = player.get_animation(animation_name)
    var peak_time: float = _find_fully_open_time(animation)
    if peak_time < 0.0:
        instance.queue_free()
        return {"ok": false, "error": "fully-open frame not found", "job": job}

    print("camera_fov=%.3f" % camera.fov)
    print("camera_transform=%s" % camera.transform)
    print("peak_time=%.6f" % peak_time)

    player.play(animation_name)
    player.pause()
    player.seek(peak_time, true)

    for _i in range(4):
        await process_frame
    await RenderingServer.frame_post_draw

    var texture: Texture2D = subviewport.get_texture()
    if texture == null:
        instance.queue_free()
        return {"ok": false, "error": "SubViewport texture null", "job": job}

    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        instance.queue_free()
        return {"ok": false, "error": "SubViewport image null/empty", "job": job}

    var used: Rect2i = image.get_used_rect()
    print("used_rect=%s" % used)
    if used.size.x <= 1 or used.size.y <= 1:
        instance.queue_free()
        return {"ok": false, "error": "render contains no useful pixels", "job": job}

    var out_abs: String = ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, slug])
    var err: Error = image.save_png(out_abs)
    if err != OK:
        instance.queue_free()
        return {"ok": false, "error": "PNG save failed", "job": job}

    var result := {
        "ok": true,
        "scene": scene_path,
        "animation": String(animation_name),
        "slug": slug,
        "peak_time": peak_time,
        "camera_fov": camera.fov,
        "camera_transform": str(camera.transform),
        "used_rect": {
            "x": used.position.x,
            "y": used.position.y,
            "w": used.size.x,
            "h": used.size.y,
        },
        "png": "%s.png" % slug,
        "image": image,
    }

    instance.queue_free()
    await process_frame
    print("JOB_OK animation=%s png=%s" % [String(animation_name), out_abs])
    return result

func _run() -> void:
    print("CAMERA_KEY_HARVEST_START")

    var out_abs: String = ProjectSettings.globalize_path(OUT_DIR)
    DirAccess.make_dir_recursive_absolute(out_abs)

    root.size = Vector2i(FRAME_SIZE, FRAME_SIZE)
    root.transparent_bg = true
    RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))

    var results: Array[Dictionary] = []
    var images: Array[Image] = []

    for job in JOBS:
        var result: Dictionary = await _render_job(job)
        if not bool(result.get("ok", false)):
            push_error("Harvest failed: %s" % result)
            quit(2)
            return
        images.append(result["image"])
        result.erase("image")
        results.append(result)

    # Compact review/use sheet: 4 columns x 2 rows, fixed 760px cells.
    var columns: int = 4
    var rows: int = 2
    var sheet := Image.create(columns * FRAME_SIZE, rows * FRAME_SIZE, false, Image.FORMAT_RGBA8)
    sheet.fill(Color(0.0, 0.0, 0.0, 0.0))

    for i in range(images.size()):
        var x: int = (i % columns) * FRAME_SIZE
        var y: int = (i / columns) * FRAME_SIZE
        sheet.blit_rect(images[i], Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE), Vector2i(x, y))

    var sheet_abs: String = ProjectSettings.globalize_path("%s/diorama_slash_camera_keys.png" % OUT_DIR)
    var sheet_err: Error = sheet.save_png(sheet_abs)
    if sheet_err != OK:
        push_error("Failed to save compact camera-key sheet")
        quit(3)
        return

    var manifest := {
        "schema": "diorama-slash-camera-keys-v1",
        "frame_size": FRAME_SIZE,
        "columns": columns,
        "rows": rows,
        "key_count": results.size(),
        "selection_rule": "first authored time where progress >= 0.999 and collapse <= 0.001",
        "authority": [
            "native Godot scene",
            "native 3D mesh",
            "native animation transform",
            "native Camera3D transform and FOV",
            "native shader/material",
            "real OpenGL rendering under Xvfb/llvmpipe",
        ],
        "keys": results,
        "sheet": "diorama_slash_camera_keys.png",
    }

    var manifest_abs: String = ProjectSettings.globalize_path("%s/manifest.json" % OUT_DIR)
    var file := FileAccess.open(manifest_abs, FileAccess.WRITE)
    if file == null:
        push_error("Failed to write manifest")
        quit(4)
        return
    file.store_string(JSON.stringify(manifest, "  ") + "\n")
    file.close()

    print("")
    print("CAMERA_KEY_HARVEST_OK")
    print("keys=%d" % results.size())
    print("sheet=%s" % sheet_abs)
    print("manifest=%s" % manifest_abs)
    quit(0)
