extends Node3D

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 12
const MAP_WIDTH: int = GRID_WIDTH
const MAP_HEIGHT: int = GRID_HEIGHT
const TILE_SIZE: float = 1.5
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
const SPRITE_PIXEL_SIZE: float = 1.0 / 128.0
const CHARACTER_PIXEL_SIZE: float = 1.0 / 1024.0
const ROCK_VERTICAL_STRETCH: float = 1.33
const ROCK_SCALE_FACTOR: float = 0.1839783

const JOYSTICK_SCRIPT: Script = preload("res://scripts/joystick.gd")
const JOYSTICK_PATH: String = "res://assets/legacy/diorama-of-descension/sprites/JoystickZones.png"
const PLAYER_FRONT_PATH: String = "res://assets/textures/Player.png"
const PLAYER_BACK_PATH: String = "res://assets/textures/Player.png"
const PLAYER_SIDE_PATH: String = "res://assets/textures/Player.png"
const GOBLIN_FRONT_PATH: String = "res://assets/textures/RedGhost.png"
const GOBLIN_BACK_PATH: String = "res://assets/textures/RedGhost.png"
const GOBLIN_SIDE_PATH: String = "res://assets/textures/RedGhost.png"
const FLOOR_PATH: String = "res://assets/textures/DescenantFloor.png"
const ROCK_PATH: String = "res://assets/textures/Rock.png"
const MAP_GENERATOR = preload("res://scripts/world/map_generator.gd")

var background_texture: Texture2D
var joystick_texture: Texture2D
var player_front_texture: Texture2D
var player_back_texture: Texture2D
var player_side_texture: Texture2D
var goblin_front_texture: Texture2D
var goblin_back_texture: Texture2D
var goblin_side_texture: Texture2D
var rock_texture: Texture2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var map_state: Array = []
var start_cell: Vector2i = Vector2i.ZERO
var goal_cell: Vector2i = Vector2i.ZERO
var player_cell: Vector2i = Vector2i(3, 8)
var enemy_cell: Vector2i = Vector2i(3, 0)
var enemy_target_cell: Vector2i = Vector2i(3, 0)
var player_hold_time: float = 0.0
var enemy_turn_active: bool = false
var enemy_turn_timer: float = 0.0
var rock_cells: Dictionary = {}
var player_sprite: MeshInstance3D
var enemy_sprite: MeshInstance3D
var telegraph_tile: MeshInstance3D
var status_label: Label
var camera: Camera3D
var joystick: Control
var scene_root: Node3D
var floor_root: Node3D
var actor_root: Node3D


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
	var direction: Vector2i = _get_input_direction()

	if direction == Vector2i.ZERO:
		player_hold_time = 0.0
	else:
		player_hold_time += delta

		if not enemy_turn_active and player_hold_time >= PLAYER_STEP_INTERVAL:
			player_hold_time -= PLAYER_STEP_INTERVAL
			if _try_move_player(direction):
				_begin_enemy_telegraph()

	if enemy_turn_active:
		enemy_turn_timer += delta
		var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.01) * 0.05
		telegraph_tile.scale = Vector3(pulse, 1.0, pulse)

		if enemy_turn_timer >= ENEMY_TELEGRAPH_TIME:
			_resolve_enemy_move()

	_update_status_label()


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

	player_sprite = get_node_or_null("PlayerSprite") as MeshInstance3D

	floor_root = Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)

	actor_root = Node3D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	_create_hud()
	_create_joystick()


func _create_player() -> void:
	if player_sprite != null:
		_configure_billboard_mesh(player_sprite, player_front_texture, Vector2(1.75, 2.25))
		return

	player_sprite = _create_card_sprite(player_front_texture, Vector2(1.75, 2.25))
	player_sprite.name = "Player"
	actor_root.add_child(player_sprite)


func _create_enemy() -> void:
	enemy_sprite = _create_card_sprite(goblin_front_texture, Vector2(1.45, 1.95))
	enemy_sprite.name = "Goblin"
	actor_root.add_child(enemy_sprite)


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
	_clear_children(floor_root)
	_clear_children(actor_root)
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
	var rock: MeshInstance3D = _create_billboard_mesh(rock_texture, Vector2(1.35, 1.95))
	rock.position = _cell_to_world(cell) + Vector3(0.0, 0.55, 0.0)
	actor_root.add_child(rock)


func _make_highlight_tile() -> MeshInstance3D:
	var tile: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(TILE_SIZE * 0.9, 0.16, TILE_SIZE * 0.9)
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


func _create_card_sprite(texture: Texture2D, quad_size: Vector2) -> MeshInstance3D:
	var sprite: MeshInstance3D = _create_billboard_mesh(texture, quad_size)
	sprite.position.y = 0.9
	return sprite


func _create_billboard_mesh(texture: Texture2D, quad_size: Vector2) -> MeshInstance3D:
	var sprite: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = quad_size
	sprite.mesh = quad
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sprite.material_override = material
	return sprite


func _configure_billboard_mesh(node: MeshInstance3D, texture: Texture2D, quad_size: Vector2) -> void:
	if node == null:
		return

	var quad: QuadMesh = node.mesh as QuadMesh

	if quad == null:
		quad = QuadMesh.new()
		node.mesh = quad

	quad.size = quad_size

	var material: StandardMaterial3D = node.material_override as StandardMaterial3D

	if material == null:
		material = StandardMaterial3D.new()
		node.material_override = material

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _refresh_actor_positions() -> void:
	_move_sprite_to_cell(player_sprite, player_cell)
	_move_sprite_to_cell(enemy_sprite, enemy_cell)
	_update_player_facing(Vector2i(0, -1))
	_update_enemy_facing(_enemy_direction_toward_player())


func _move_sprite_to_cell(sprite: Node3D, cell: Vector2i) -> void:
	if sprite == null:
		return

	sprite.position = _cell_to_world(cell) + Vector3(0.0, 0.9, 0.0)


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
		_move_sprite_to_cell(enemy_sprite, enemy_cell)

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
	_move_sprite_to_cell(player_sprite, player_cell)
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
	return Vector3((float(cell.x) - half_width) * TILE_SIZE, 0.0, (float(cell.y) - half_height) * TILE_SIZE)


func _get_input_direction() -> Vector2i:
	var vector: Vector2 = Vector2.ZERO

	if joystick != null:
		vector = joystick.get_input_vector()

	if vector == Vector2.ZERO:
		vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	return _snap_cardinal_direction(vector)


func _snap_cardinal_direction(vector: Vector2) -> Vector2i:
	if vector.length() < 0.25:
		return Vector2i.ZERO

	var abs_x: float = abs(vector.x)
	var abs_y: float = abs(vector.y)

	if abs_x == abs_y:
		return Vector2i.ZERO

	if abs_x > abs_y * 1.2:
		return Vector2i.RIGHT if vector.x > 0.0 else Vector2i.LEFT

	if abs_y > abs_x * 1.2:
		return Vector2i.DOWN if vector.y > 0.0 else Vector2i.UP

	return Vector2i.ZERO


func _update_player_facing(direction: Vector2i) -> void:
	if player_sprite == null:
		return

	if direction == Vector2i.ZERO:
		return

	if direction.x > 0:
		_set_billboard_texture(player_sprite, player_side_texture, false)
	elif direction.x < 0:
		_set_billboard_texture(player_sprite, player_side_texture, true)
	elif direction.y > 0:
		_set_billboard_texture(player_sprite, player_front_texture, false)
	elif direction.y < 0:
		_set_billboard_texture(player_sprite, player_back_texture, false)


func _update_enemy_facing(direction: Vector2i) -> void:
	if enemy_sprite == null:
		return

	if direction == Vector2i.ZERO:
		return

	if direction.x > 0:
		_set_billboard_texture(enemy_sprite, goblin_side_texture, false)
	elif direction.x < 0:
		_set_billboard_texture(enemy_sprite, goblin_side_texture, true)
	elif direction.y > 0:
		_set_billboard_texture(enemy_sprite, goblin_front_texture, false)
	elif direction.y < 0:
		_set_billboard_texture(enemy_sprite, goblin_back_texture, false)


func _set_billboard_texture(node: MeshInstance3D, texture: Texture2D, flip_x: bool) -> void:
	if node == null:
		return

	var material: StandardMaterial3D = node.material_override as StandardMaterial3D

	if material == null:
		material = StandardMaterial3D.new()
		node.material_override = material

	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var base_scale: Vector3 = node.scale

	if base_scale == Vector3.ZERO:
		base_scale = Vector3.ONE

	node.scale = Vector3(-absf(base_scale.x) if flip_x else absf(base_scale.x), absf(base_scale.y), absf(base_scale.z))


func _update_status_label() -> void:
	if status_label == null:
		return

	var phase_text: String = "enemy telegraph" if enemy_turn_active else "player move"
	var move_text: String = "idle"

	if not enemy_turn_active:
		var direction: Vector2i = _get_input_direction()

		if direction != Vector2i.ZERO:
			if direction == Vector2i.UP:
				move_text = "up"
			elif direction == Vector2i.DOWN:
				move_text = "down"
			elif direction == Vector2i.LEFT:
				move_text = "left"
			elif direction == Vector2i.RIGHT:
				move_text = "right"

	status_label.text = "Diorama Descent | %s | held %.2fs | %s" % [phase_text, player_hold_time, move_text]


func _clear_children(node: Node, keep_actors: bool = false) -> void:
	if node == null:
		return

	for child in node.get_children():
		if keep_actors and (child == telegraph_tile or child == player_sprite or child == enemy_sprite):
			continue

		child.queue_free()


func _load_assets() -> void:
	joystick_texture = _load_texture(JOYSTICK_PATH)
	player_front_texture = _load_texture(PLAYER_FRONT_PATH)
	player_back_texture = _load_texture(PLAYER_BACK_PATH)
	player_side_texture = _load_texture(PLAYER_SIDE_PATH)
	goblin_front_texture = _load_texture(GOBLIN_FRONT_PATH)
	goblin_back_texture = _load_texture(GOBLIN_BACK_PATH)
	goblin_side_texture = _load_texture(GOBLIN_SIDE_PATH)
	background_texture = _load_texture(FLOOR_PATH)
	rock_texture = _load_texture(ROCK_PATH)

	if player_sprite != null and player_front_texture == null:
		player_front_texture = player_sprite.texture

	if player_sprite != null and player_back_texture == null:
		player_back_texture = player_sprite.texture

	if player_sprite != null and player_side_texture == null:
		player_side_texture = player_sprite.texture


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
	if OS.has_feature("android"):
		var resource: Resource = ResourceLoader.load(path)

		if resource is Texture2D:
			return resource

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image != null and image.get_size() != Vector2i.ZERO:
		return ImageTexture.create_from_image(image)

	if not OS.has_feature("android"):
		var resource: Resource = ResourceLoader.load(path)

		if resource is Texture2D:
			return resource

	push_error("Failed to load texture at %s" % path)
	return null
