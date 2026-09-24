extends SceneTree

const SLASH_SCENE := preload("res://scenes/Slash.tscn")
const DEFAULT_FPS := 60
const DEFAULT_FRAME_SIZE := 768
const DEFAULT_COLUMNS := 8
const OUTPUT_DIR := "res://generated/slash-sprite-sheet"

var sample_fps := DEFAULT_FPS
var frame_size := DEFAULT_FRAME_SIZE
var columns := DEFAULT_COLUMNS

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

func _parse_args() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--fps="):
            sample_fps = max(1, int(arg.trim_prefix("--fps=")))
        elif arg.begins_with("--frame-size="):
            frame_size = max(64, int(arg.trim_prefix("--frame-size=")))
        elif arg.begins_with("--columns="):
            columns = max(1, int(arg.trim_prefix("--columns=")))

func _run() -> void:
    print("SLASH_EXPORT_START")
    _parse_args()

    var out_abs := ProjectSettings.globalize_path(OUTPUT_DIR)
    DirAccess.make_dir_recursive_absolute(out_abs)
    DirAccess.make_dir_recursive_absolute(out_abs.path_join("frames"))

    root.size = Vector2i(frame_size, frame_size)
    root.transparent_bg = true
    RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))

    print("instantiating Slash.tscn")
    var probe = SLASH_SCENE.instantiate()
    root.add_child(probe)
    print("Slash.tscn instantiated")
    probe.position = Vector2(frame_size * 0.5, frame_size * 0.5)

    var player: AnimationPlayer = probe.get_node("AnimationPlayer")
    _strip_empty_animation_tracks(player)
    var animation_names: Array[StringName] = []
    for name in player.get_animation_list():
        if String(name) != "RESET":
            animation_names.append(name)
    animation_names.sort_custom(func(a, b): return String(a) < String(b))

    var frame_plan: Array[Dictionary] = []
    for anim_name in animation_names:
        var anim := player.get_animation(anim_name)
        if anim == null:
            continue
        var length: float = maxf(float(anim.length), 0.001)
        var count := int(floor(length * sample_fps)) + 1
        for i in range(count):
            var t: float = minf(float(i) / float(sample_fps), maxf(length - 0.000001, 0.0))
            frame_plan.append({
                "animation": String(anim_name),
                "time": t,
                "length": length,
                "local_index": i,
            })

    if frame_plan.is_empty():
        push_error("No slash animations found.")
        probe.queue_free()
        quit(2)
        return

    var rows := int(ceil(float(frame_plan.size()) / float(columns)))
    var sheet := Image.create(columns * frame_size, rows * frame_size, false, Image.FORMAT_RGBA8)
    sheet.fill(Color(0.0, 0.0, 0.0, 0.0))

    var manifest_frames: Array[Dictionary] = []
    var global_index := 0

    for item in frame_plan:
        var anim_name := StringName(item["animation"])
        var t := float(item["time"])
        var local_index := int(item["local_index"])

        print("render %s frame %d @ %.4fs" % [String(anim_name), local_index, t])
        player.play(anim_name)
        player.pause()
        player.seek(t, true)

        # In phone/PRoot headless mode frame_post_draw may never fire.
        # Two SceneTree frames are enough for AnimationPlayer + SubViewport state
        # to settle without depending on a display-server draw signal.
        await process_frame
        await process_frame

        var image := root.get_texture().get_image()
        if image.get_width() != frame_size or image.get_height() != frame_size:
            image.resize(frame_size, frame_size, Image.INTERPOLATE_LANCZOS)

        var safe_name := String(anim_name).to_snake_case()
        var frame_file := "%s_%04d.png" % [safe_name, local_index]
        var frame_path := out_abs.path_join("frames").path_join(frame_file)
        var err := image.save_png(frame_path)
        if err != OK:
            push_error("Failed to save frame: %s" % frame_path)
            probe.queue_free()
            quit(3)
            return

        var cell_x := (global_index % columns) * frame_size
        var cell_y := (global_index / columns) * frame_size
        sheet.blit_rect(
            image,
            Rect2i(0, 0, frame_size, frame_size),
            Vector2i(cell_x, cell_y)
        )

        manifest_frames.append({
            "index": global_index,
            "animation": String(anim_name),
            "local_index": local_index,
            "time_seconds": t,
            "file": "frames/%s" % frame_file,
            "sheet_col": global_index % columns,
            "sheet_row": global_index / columns,
        })
        global_index += 1

    var sheet_path := out_abs.path_join("diorama_slash_full_sheet.png")
    var sheet_err := sheet.save_png(sheet_path)
    if sheet_err != OK:
        push_error("Failed to save sheet: %s" % sheet_path)
        probe.queue_free()
        quit(4)
        return

    var manifest := {
        "schema": "diorama-slash-full-sheet-v1",
        "source_scene": "res://scenes/Slash.tscn",
        "fps": sample_fps,
        "frame_size": frame_size,
        "columns": columns,
        "rows": rows,
        "frame_count": manifest_frames.size(),
        "animations": animation_names.map(func(n): return String(n)),
        "frames": manifest_frames,
        "sheet": "diorama_slash_full_sheet.png",
        "contract": {
            "full_native_animation_sampling": true,
            "fixed_canvas": true,
            "transparent_background": true,
            "per_frame_crop": false,
            "auto_center": false,
            "source_material_and_animation": true,
        },
    }

    var manifest_path := out_abs.path_join("manifest.json")
    var file := FileAccess.open(manifest_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to open manifest: %s" % manifest_path)
        probe.queue_free()
        quit(5)
        return
    file.store_string(JSON.stringify(manifest, "  ") + "\n")
    file.close()

    print("SLASH_SHEET_OK")
    print("sheet=%s" % sheet_path)
    print("manifest=%s" % manifest_path)
    print("frames=%d" % manifest_frames.size())
    print("animations=%s" % ", ".join(animation_names.map(func(n): return String(n))))

    probe.queue_free()
    quit(0)
