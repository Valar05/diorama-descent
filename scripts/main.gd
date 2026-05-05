extends Node3D

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 13
const MAP_WIDTH: int = GRID_WIDTH
const MAP_HEIGHT: int = GRID_HEIGHT
const TILE_SIZE: float = 1.5
const GRID_ROW_SIZE: float = 1.68
const GRID_WORLD_Z_OFFSET: float = GRID_ROW_SIZE * 1.25
const PLAYER_STEP_INTERVAL: float = 1.0
const ENEMY_TELEGRAPH_TIME: float = 0.85
const MIN_CRITICAL_PATH_LENGTH: int = 14
const MAX_CRITICAL_PATH_LENGTH: int = 22
const PATH_BUILD_ATTEMPTS: int = 48
const MIN_BRANCH_COUNT: int = 2
const MAX_BRANCH_COUNT: int = 4
const MIN_BRANCH_LENGTH: int = 2
const MAX_BRANCH_LENGTH: int = 4
const MIN_ROOM_COUNT: int = 2
const MAX_ROOM_COUNT: int = 4
const ROCK_VERTICAL_STRETCH: float = 1.33
const ROCK_SCALE_FACTOR: float = 0.1839783
const ROCK_SPRITE_SIZE: Vector2 = Vector2(1.25, 1.25)
const PLAYER_HOP_HEIGHT: float = 0.22
const GOBLIN_HOP_HEIGHT: float = 0.18
const PLAYER_SHADOW_SQUASH: float = 0.12
const GOBLIN_SHADOW_SQUASH: float = 0.10

# Use the checked-in source textures from the legacy project so the runtime does
# not depend on hash-specific `.ctex` files in `.godot/imported/`.
const JOYSTICK_SCRIPT: Script = preload("res://scripts/joystick.gd")
const PLAYER_ACTOR_SCENE: PackedScene = preload("res://scenes/actors/PlayerActor.tscn")
const GOBLIN_ACTOR_SCENE: PackedScene = preload("res://scenes/actors/GoblinActor.tscn")
const JOYSTICK_PATH: String = "res://.godot/imported/JoystickZones.png-c30a5716e02ebb582100e4b51407575f.ctex"
const BACKGROUND_PATH: String = "res://.godot/imported/BackgroundHorizontal.png-cc16607e0356e38753ace879d0a17c42.ctex"
const ROCK_PATH: String = "res://.godot/imported/Rock.png-f2a54fbe1b75f2790580fd397d314ea3.ctex"
const MAP_GENERATOR = preload("res://scripts/world/map_generator.gd")

var background_texture: Texture2D
var joystick_texture: Texture2D
var rock_texture: Texture2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var map_state: Array = []
var start_cell: Vector2i = Vector2i.ZERO
var goal_cell: Vector2i = Vector2i.ZERO
var player_cell: Vector2i = Vector2i(3, 8)
var enemy_cell: Vector2i = Vector2i(3, 0)
var enemy_target_cell: Vector2i = Vector2i(3, 0)
var player_hold_time: float = 0.0
var player_step_timer: float = 0.0
var player_last_direction: Vector2i = Vector2i.ZERO
var enemy_turn_active: bool = false
var enemy_turn_timer: float = 0.0
var rock_cells: Dictionary = {}
var player_actor
var enemy_actor
var player_sprite: Sprite3D
var player_shadow: Sprite3D
var enemy_sprite: Sprite3D
var enemy_shadow: Sprite3D
var telegraph_tile: MeshInstance3D
var status_label: Label
var camera: Camera3D
var joystick: Control
var scene_root: Node3D
var floor_root: Node3D
var actor_root: Node3D
var player_move_tween: Tween
var enemy_move_tween: Tween


func _ready() -> void:
	rng.randomize()
	_build_scene()
	_load_assets()
	_apply_floor_texture()
	_generate_layout()
	_refresh_actor_positions()
	_begin_enemy_telegraph()
	_update_status_label()


func _process(delta: float) -> void:
	_update_enemy_turn(delta)
	var direction: Vector2i = _get_input_direction()
	_update_player_hold(direction, delta)
	_update_status_label()


func _update_enemy_turn(delta: float) -> void:
	if not enemy_turn_active:
		return

	enemy_turn_timer += delta
	var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.01) * 0.05
	telegraph_tile.scale = Vector3(pulse, 1.0, pulse)

	if enemy_turn_timer >= ENEMY_TELEGRAPH_TIME:
		_resolve_enemy_move()


func _update_player_hold(direction: Vector2i, delta: float) -> void:
	if direction == Vector2i.ZERO:
		player_hold_time = 0.0
		player_step_timer = 0.0
		player_last_direction = Vector2i.ZERO
		return

	if direction != player_last_direction:
		player_last_direction = direction
		player_hold_time = 0.0
		player_step_timer = PLAYER_STEP_INTERVAL
	else:
		player_hold_time += delta
		player_step_timer += delta

	if enemy_turn_active:
		return

	if player_step_timer < PLAYER_STEP_INTERVAL:
		return

	player_step_timer = fmod(player_step_timer, PLAYER_STEP_INTERVAL)
	if _try_move_player(direction):
		_begin_enemy_telegraph()
	else:
		player_step_timer = 0.0


func _build_scene() -> void:
	scene_root = self

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.08, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.62, 0.55)
	environment.ambient_light_energy = 1.0
	world_environment.environment = environment
	add_child(world_environment)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.5
	add_child(light)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.position = Vector3(0.0, 16.0, 16.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var floor: MeshInstance3D = get_node_or_null("FloorBackdrop") as MeshInstance3D

	if floor == null:
		floor = MeshInstance3D.new()
		floor.name = "FloorBackdrop"
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(18.0, 32.0)
		floor.mesh = plane
		floor.position = Vector3(0.0, -0.08, 0.0)
		floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var floor_material: StandardMaterial3D = StandardMaterial3D.new()
		floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_material.albedo_texture = background_texture
		floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		floor_material.roughness = 1.0
		floor.material_override = floor_material
		add_child(floor)

	floor_root = Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)

	actor_root = Node3D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	_create_hud()
	_create_joystick()


func _create_player() -> void:
	if player_actor == null or not is_instance_valid(player_actor):
		player_actor = PLAYER_ACTOR_SCENE.instantiate()
		player_actor.name = "PlayerActor"
		actor_root.add_child(player_actor)

	player_sprite = player_actor.get_body()
	player_shadow = player_actor.get_shadow()
	player_actor.reset_visuals()


func _create_enemy() -> void:
	if enemy_actor == null or not is_instance_valid(enemy_actor):
		enemy_actor = GOBLIN_ACTOR_SCENE.instantiate()
		enemy_actor.name = "GoblinActor"
		actor_root.add_child(enemy_actor)

	enemy_sprite = enemy_actor.get_body()
	enemy_shadow = enemy_actor.get_shadow()
	enemy_actor.reset_visuals()


func _create_hud() -> void:
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	var hud_root: Control = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	status_label = Label.new()
	status_label.position = Vector2(24.0, 20.0)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
	status_label.text = "..."
	hud_root.add_child(status_label)


func _create_joystick() -> void:
	var ui_layer: CanvasLayer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)

	var joystick_root: Control = Control.new()
	joystick_root.name = "Joystick"
	joystick_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick_root.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick_root.position = Vector2.ZERO

	var base: Sprite2D = Sprite2D.new()
	base.name = "base"
	base.scale = Vector2(0.33, 0.33)
	base.texture = joystick_texture
	joystick_root.add_child(base)

	var pip: Node2D = Node2D.new()
	pip.name = "JoystickPip"
	base.add_child(pip)

	joystick_root.script = JOYSTICK_SCRIPT
	ui_layer.add_child(joystick_root)
	joystick_root.set_meta("input_owner", self)
	joystick = joystick_root


func _generate_layout() -> void:
	_initialize_map_state()
	rock_cells.clear()
	if player_move_tween != null:
		player_move_tween.kill()
		player_move_tween = null
	if enemy_move_tween != null:
		enemy_move_tween.kill()
		enemy_move_tween = null
	_clear_children(floor_root)
	_clear_children(actor_root)
	player_actor = null
	enemy_actor = null
	player_sprite = null
	player_shadow = null
	enemy_sprite = null
	enemy_shadow = null
	telegraph_tile = _make_highlight_tile()
	telegraph_tile.visible = false
	actor_root.add_child(telegraph_tile)
	player_cell = start_cell
	enemy_cell = goal_cell
	_create_player()
	_create_enemy()
	_spawn_rocks()
	_refresh_actor_positions()
	_begin_enemy_telegraph()


func _initialize_map_state() -> void:
	MAP_GENERATOR.initialize_map_state(self)


func _generate_map() -> void:
	MAP_GENERATOR.generate_map(self)


func _build_critical_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return MAP_GENERATOR.build_critical_path(self, start, goal)


func _extend_critical_path(current: Vector2i, goal: Vector2i, path: Array[Vector2i], visited: Dictionary) -> bool:
	return MAP_GENERATOR.extend_critical_path(self, current, goal, path, visited)


func _get_scored_neighbors(current: Vector2i, goal: Vector2i, visited: Dictionary, path: Array[Vector2i]) -> Array[Vector2i]:
	return MAP_GENERATOR.get_scored_neighbors(self, current, goal, visited, path)


func _count_future_options(cell: Vector2i, visited: Dictionary) -> int:
	return MAP_GENERATOR.count_future_options(self, cell, visited)


func _build_fallback_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return MAP_GENERATOR.build_fallback_path(self, start, goal)


func _carve_branches(critical_path: Array[Vector2i]) -> Array[Vector2i]:
	return MAP_GENERATOR.carve_branches(self, critical_path)


func _build_branch(anchor_cell: Vector2i, target_length: int) -> Array[Vector2i]:
	return MAP_GENERATOR.build_branch(self, anchor_cell, target_length)


func _carve_rooms(critical_path: Array[Vector2i], branch_cells: Array[Vector2i]) -> void:
	MAP_GENERATOR.carve_rooms(self, critical_path, branch_cells)


func _carve_room(anchor_cell: Vector2i, room_size: Vector2i) -> bool:
	return MAP_GENERATOR.carve_room(self, anchor_cell, room_size)


func _shuffle_cells(cells: Array) -> void:
	for index in range(cells.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var cached_value: Variant = cells[index]
		cells[index] = cells[swap_index]
		cells[swap_index] = cached_value


func _set_cell_occupied(cell: Vector2i, is_occupied: bool) -> void:
	map_state[cell.y][cell.x] = is_occupied


func _is_cell_occupied(cell: Vector2i) -> bool:
	return map_state[cell.y][cell.x]


func _count_open_neighbors(cell: Vector2i) -> int:
	var count: int = 0

	for direction in _get_cardinal_directions():
		var next_cell: Vector2i = cell + direction

		if not _is_in_bounds(next_cell):
			continue

		if not _is_cell_occupied(next_cell):
			count += 1

	return count


func _count_surrounding_rocks(cell: Vector2i) -> int:
	var count: int = 0

	for direction in _get_cardinal_directions():
		var next_cell: Vector2i = cell + direction

		if not _is_in_bounds(next_cell):
			continue

		if _is_cell_occupied(next_cell):
			count += 1

	return count


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func _manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)


func _get_cardinal_directions() -> Array[Vector2i]:
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


func _spawn_rocks() -> void:
	for row_index in range(GRID_HEIGHT):
		for column_index in range(GRID_WIDTH):
			if not map_state[row_index][column_index]:
				continue

			var cell: Vector2i = Vector2i(column_index, row_index)
			rock_cells[cell] = true
			_spawn_rock(cell)


func _spawn_rock(cell: Vector2i) -> void:
	var rock: MeshInstance3D = _create_billboard_mesh(rock_texture, ROCK_SPRITE_SIZE)
	rock.position = _cell_to_world(cell) + Vector3(0.0, 0.55, 0.0)
	actor_root.add_child(rock)


func _make_highlight_tile() -> MeshInstance3D:
	var tile: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(TILE_SIZE * 0.9, 0.16, GRID_ROW_SIZE * 0.9)
	tile.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.42, 0.12, 0.32)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.08)
	tile.material_override = material
	tile.position = Vector3.ZERO
	tile.position.y = 0.04
	return tile


func _create_billboard_mesh(texture: Texture2D, size: Vector2) -> MeshInstance3D:
	var sprite: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	sprite.mesh = quad
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sprite.material_override = material
	return sprite


func _refresh_actor_positions() -> void:
	if player_actor != null:
		player_actor.position = _cell_to_world(player_cell) + player_actor.spawn_offset
		player_actor.reset_visuals()
		player_actor.set_facing(Vector2i(0, -1))

	if enemy_actor != null:
		enemy_actor.position = _cell_to_world(enemy_cell) + enemy_actor.spawn_offset
		enemy_actor.reset_visuals()
		enemy_actor.set_facing(_enemy_direction_toward_player())


func _move_actor_to_cell(actor, cell: Vector2i) -> void:
	if actor == null:
		return

	actor.position = _cell_to_world(cell) + actor.spawn_offset
	actor.reset_visuals()


func _hop_actor_to_cell(actor, cell: Vector2i, duration: float, hop_height: float, shadow_squash: float, is_player: bool) -> void:
	if actor == null:
		return

	if is_player:
		if player_move_tween != null:
			player_move_tween.kill()
			player_move_tween = null
	else:
		if enemy_move_tween != null:
			enemy_move_tween.kill()
			enemy_move_tween = null

	var body: Sprite3D = actor.get_body()
	var shadow: Sprite3D = actor.get_shadow()
	var start_actor: Vector3 = actor.position
	var target_actor: Vector3 = _cell_to_world(cell) + actor.spawn_offset
	var start_body: Vector3 = body.position if body != null else Vector3.ZERO
	var target_body: Vector3 = Vector3(start_body.x, start_body.y, start_body.z)
	var start_shadow: Vector3 = shadow.position if shadow != null else Vector3.ZERO
	var target_shadow: Vector3 = Vector3(start_shadow.x, start_shadow.y, start_shadow.z)
	var shadow_scale: Vector3 = shadow.scale if shadow != null else Vector3.ONE

	var tween: Tween = create_tween()
	tween.tween_method(
		Callable(self, "_apply_actor_hop_progress").bind(actor, body, shadow, start_actor, target_actor, start_body, target_body, start_shadow, target_shadow, shadow_scale, hop_height, shadow_squash),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_player:
		player_move_tween = tween
	else:
		enemy_move_tween = tween


func _apply_actor_hop_progress(progress: float, actor, body: Sprite3D, shadow: Sprite3D, start_actor: Vector3, target_actor: Vector3, start_body: Vector3, target_body: Vector3, start_shadow: Vector3, target_shadow: Vector3, shadow_scale: Vector3, hop_height: float, shadow_squash: float) -> void:
	if actor == null:
		return

	var arc: float = sin(PI * progress)
	actor.position = start_actor.lerp(target_actor, progress)

	if body != null:
		body.position = start_body.lerp(target_body, progress) + Vector3(0.0, arc * hop_height, 0.0)

	if shadow != null:
		shadow.position = start_shadow.lerp(target_shadow, progress)
		var squash: float = 1.0 - arc * shadow_squash
		shadow.scale = Vector3(shadow_scale.x * squash, shadow_scale.y * squash, shadow_scale.z)


func _begin_enemy_telegraph() -> void:
	enemy_target_cell = _choose_enemy_step()
	enemy_turn_active = true
	enemy_turn_timer = 0.0
	telegraph_tile.visible = true
	telegraph_tile.position = _cell_to_world(enemy_target_cell) + Vector3(0.0, 0.04, 0.0)
	telegraph_tile.scale = Vector3.ONE
	_update_enemy_facing(_enemy_direction_toward_player())
	_update_status_label()


func _resolve_enemy_move() -> void:
	enemy_turn_active = false
	enemy_turn_timer = 0.0

	if enemy_target_cell != enemy_cell:
		enemy_cell = enemy_target_cell
		_hop_actor_to_cell(enemy_actor, enemy_cell, 0.16, GOBLIN_HOP_HEIGHT, GOBLIN_SHADOW_SQUASH, false)

	telegraph_tile.visible = false
	_update_enemy_facing(_enemy_direction_toward_player())
	_update_status_label()


func _choose_enemy_step() -> Vector2i:
	var delta: Vector2i = player_cell - enemy_cell
	var horizontal_first: bool = abs(delta.x) >= abs(delta.y)
	var candidates: Array[Vector2i] = []

	if horizontal_first:
		if delta.x != 0:
			candidates.append(enemy_cell + Vector2i(signi(delta.x), 0))

		if delta.y != 0:
			candidates.append(enemy_cell + Vector2i(0, signi(delta.y)))
	else:
		if delta.y != 0:
			candidates.append(enemy_cell + Vector2i(0, signi(delta.y)))

		if delta.x != 0:
			candidates.append(enemy_cell + Vector2i(signi(delta.x), 0))

	candidates.append(enemy_cell)

	for candidate in candidates:
		if _is_cell_available(candidate):
			return candidate

	return enemy_cell


func _enemy_direction_toward_player() -> Vector2i:
	var delta: Vector2i = player_cell - enemy_cell

	if abs(delta.x) >= abs(delta.y):
		if delta.x > 0:
			return Vector2i.RIGHT
		if delta.x < 0:
			return Vector2i.LEFT

	if delta.y > 0:
		return Vector2i.DOWN
	if delta.y < 0:
		return Vector2i.UP

	return Vector2i.ZERO


func _try_move_player(direction: Vector2i) -> bool:
	var target: Vector2i = player_cell + direction

	if not _is_cell_available(target):
		player_hold_time = 0.0
		_update_status_label()
		return false

	player_cell = target
	_hop_actor_to_cell(player_actor, player_cell, 0.18, PLAYER_HOP_HEIGHT, PLAYER_SHADOW_SQUASH, true)
	_update_player_facing(direction)
	_update_status_label()
	return true


func _is_cell_available(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false

	if rock_cells.has(cell):
		return false

	if cell == player_cell and enemy_turn_active:
		return false

	if cell == enemy_cell:
		return false

	return true


func _cell_to_world(cell: Vector2i) -> Vector3:
	var half_width: float = float(GRID_WIDTH - 1) * 0.5
	var half_height: float = float(GRID_HEIGHT - 1) * 0.5
	return Vector3((float(cell.x) - half_width) * TILE_SIZE, 0.0, (float(cell.y) - half_height) * GRID_ROW_SIZE + GRID_WORLD_Z_OFFSET)


func _get_input_direction() -> Vector2i:
	var vector: Vector2 = Vector2.ZERO

	if joystick != null:
		vector = joystick.get_input_vector()

	if vector == Vector2.ZERO:
		vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	return _snap_grid_direction(vector)


func _snap_grid_direction(vector: Vector2) -> Vector2i:
	if vector.length() < 0.25:
		return Vector2i.ZERO

	var abs_x: float = abs(vector.x)
	var abs_y: float = abs(vector.y)

	if abs_x == abs_y:
		return Vector2i(signi(vector.x), signi(vector.y))

	if abs_x > abs_y * 1.2:
		return Vector2i.RIGHT if vector.x > 0.0 else Vector2i.LEFT

	if abs_y > abs_x * 1.2:
		return Vector2i.DOWN if vector.y > 0.0 else Vector2i.UP

	return Vector2i(signi(vector.x), signi(vector.y))


func _update_player_facing(direction: Vector2i) -> void:
	if player_actor == null:
		return

	if direction == Vector2i.ZERO:
		return

	player_actor.set_facing(direction)


func _update_enemy_facing(direction: Vector2i) -> void:
	if enemy_actor == null:
		return

	if direction == Vector2i.ZERO:
		return

	enemy_actor.set_facing(direction)


func _update_status_label() -> void:
	if status_label == null:
		return

	var phase_text: String = "enemy telegraph" if enemy_turn_active else "player move"
	var direction: Vector2i = _get_input_direction()
	var move_text: String = _direction_to_text(direction)

	status_label.text = "Diorama Descent | %s | held %.2fs | %s" % [phase_text, player_hold_time, move_text]


func _direction_to_text(direction: Vector2i) -> String:
	if direction == Vector2i.ZERO:
		return "idle"

	var parts: Array[String] = []

	if direction.y < 0:
		parts.append("up")
	elif direction.y > 0:
		parts.append("down")

	if direction.x < 0:
		parts.append("left")
	elif direction.x > 0:
		parts.append("right")

	return "-".join(parts)


func _clear_children(node: Node, keep_actors: bool = false) -> void:
	if node == null:
		return

	for child in node.get_children():
		if keep_actors and (child == telegraph_tile or child == player_actor or child == enemy_actor):
			continue

		child.queue_free()


func _load_assets() -> void:
	joystick_texture = _load_texture(JOYSTICK_PATH)
	background_texture = _load_texture(BACKGROUND_PATH)
	rock_texture = _load_texture(ROCK_PATH)


func _apply_floor_texture() -> void:
	var floor: MeshInstance3D = get_node_or_null("FloorBackdrop") as MeshInstance3D

	if floor == null or background_texture == null:
		return

	var material: StandardMaterial3D = floor.material_override as StandardMaterial3D

	if material == null:
		material = StandardMaterial3D.new()
		floor.material_override = material

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = background_texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0


func _load_texture(path: String) -> Texture2D:
	var resource: Resource = ResourceLoader.load(path)

	if resource is Texture2D:
		return resource

	var global_path: String = ProjectSettings.globalize_path(path)
	var candidate_paths: Array[String] = [global_path]

	if global_path.find("/storage/self/primary/") == 0:
		candidate_paths.append("/storage/emulated/0/" + global_path.trim_prefix("/storage/self/primary/"))

	for candidate_path in candidate_paths:
		var image: Image = Image.load_from_file(candidate_path)

		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	push_error("Failed to load texture at %s" % path)
	return null
