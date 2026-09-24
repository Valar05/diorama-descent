extends SceneTree

const SLASH_SCENE := preload("res://scenes/Slash.tscn")
const ANIMATION_NAME := &"SlashLeft"
const OUT_PATH := "res://generated/slash-camera-keys/canary_slash_left.png"

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
            var alpha: float = (time - t0) / (t1 - t0)
            return lerpf(v0, v1, alpha)
    return float(animation.track_get_key_value(track_index, keys - 1))

func _find_fully_open_time(animation: Animation) -> float:
    var progress_path := NodePath("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/progress")
    var collapse_path := NodePath("SubViewport/WorldEnvironment/Slash:material_override:shader_parameter/collapse")
    var progress_track: int = animation.find_track(progress_path, Animation.TYPE_VALUE)
    if progress_track < 0:
        push_error("Progress track missing")
        return -1.0

    var best_time: float = -1.0
    for i in range(animation.track_get_key_count(progress_track)):
        var t: float = animation.track_get_key_time(progress_track, i)
        var progress: float = float(animation.track_get_key_value(progress_track, i))
        var collapse: float = _track_value_at(animation, collapse_path, t, 0.0)
        if progress >= 0.999 and collapse <= 0.001:
            best_time = t
            break

    if best_time >= 0.0:
        return best_time

    # Fallback scan at 1/240 s so the canary fails only if no fully-open state exists.
    var t: float = 0.0
    while t <= animation.length:
        var progress: float = _track_value_at(animation, progress_path, t, 0.0)
        var collapse: float = _track_value_at(animation, collapse_path, t, 0.0)
        if progress >= 0.999 and collapse <= 0.001:
            return t
        t += 1.0 / 240.0
    return -1.0

func _run() -> void:
    print("CAMERA_KEY_CANARY_START")
    var out_abs: String = ProjectSettings.globalize_path(OUT_PATH)
    DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())

    root.size = Vector2i(760, 760)
    root.transparent_bg = true
    RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))

    var slash := SLASH_SCENE.instantiate()
    root.add_child(slash)

    var subviewport: SubViewport = slash.get_node("SubViewport")
    subviewport.transparent_bg = true
    subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    var camera: Camera3D = slash.get_node("SubViewport/WorldEnvironment/Camera3D")
    print("camera_fov=%.3f" % camera.fov)
    print("camera_transform=%s" % camera.transform)

    var player: AnimationPlayer = slash.get_node("AnimationPlayer")
    _strip_empty_animation_tracks(player)

    if not player.has_animation(ANIMATION_NAME):
        push_error("Missing animation: %s" % String(ANIMATION_NAME))
        quit(2)
        return

    var animation: Animation = player.get_animation(ANIMATION_NAME)
    var peak_time: float = _find_fully_open_time(animation)
    if peak_time < 0.0:
        push_error("No fully-open progress=1 collapse=0 state found")
        quit(3)
        return

    print("animation=%s" % String(ANIMATION_NAME))
    print("peak_time=%.6f" % peak_time)

    player.play(ANIMATION_NAME)
    player.pause()
    player.seek(peak_time, true)

    # Give the real renderer several frames to compile shaders and draw the SubViewport.
    for _i in range(4):
        await process_frame
    await RenderingServer.frame_post_draw

    var texture: Texture2D = subviewport.get_texture()
    if texture == null:
        push_error("SubViewport texture is null; real renderer not active")
        quit(4)
        return

    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        push_error("SubViewport image is null/empty")
        quit(5)
        return

    var used: Rect2i = image.get_used_rect()
    print("image_size=%dx%d" % [image.get_width(), image.get_height()])
    print("used_rect=%s" % used)
    if used.size.x <= 1 or used.size.y <= 1:
        push_error("Rendered image contains no useful slash pixels")
        quit(6)
        return

    var err: Error = image.save_png(out_abs)
    if err != OK:
        push_error("Failed to save canary PNG: %s" % out_abs)
        quit(7)
        return

    print("CAMERA_KEY_CANARY_OK")
    print("png=%s" % out_abs)
    slash.queue_free()
    quit(0)
