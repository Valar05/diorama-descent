extends Node2D


const MAP_WIDTH: int = 7
const MAP_HEIGHT: int = 12
const ROCK_GAP_RATIO: float = 0.12
const MIN_CRITICAL_PATH_LENGTH: int = 14
const MAX_CRITICAL_PATH_LENGTH: int = 22
const PATH_BUILD_ATTEMPTS: int = 48
const MIN_BRANCH_COUNT: int = 2
const MAX_BRANCH_COUNT: int = 4
const MIN_BRANCH_LENGTH: int = 2
const MAX_BRANCH_LENGTH: int = 4
const MIN_ROOM_COUNT: int = 2
const MAX_ROOM_COUNT: int = 4
const MOVE_BUTTON_THICKNESS: float = 54.0
const MOVE_BUTTON_LENGTH_RATIO: float = 1.2
const MOVE_BUTTON_PLAYER_GAP: float = 10.0
const PLAYER_MOVE_DURATION: float = 0.25
const ENEMY_MOVE_DURATION: float = 0.125
const LONG_PRESS_DURATION: float = 0.4
const SCREEN_SHAKE_OFFSET: float = 18.0
const SCREEN_SHAKE_STEP_DURATION: float = 0.05
const BREATH_HALF_CYCLE_DURATION: float = 0.5
const BREATH_SCALE_X: float = 1.1
const BREATH_SCALE_Y: float = 1.0
const PLAYER_BREATH_SHIFT_X: float = 5.0
const PLAYER_MOVE_STRETCH_SCALE: float = 1.4
const GHOST_MOVE_STRETCH_SCALE: float = 2.0
const GHOST_DEATH_EXPAND_DURATION: float = 0.45
const GHOST_DEATH_SHRINK_DURATION: float = 0.55
const GHOST_DEATH_EXPAND_SCALE: float = 1.45
const GHOST_DEATH_SPIN_RADIANS: float = TAU * 3.0
const MINING_LUNGE_RATIO: float = 0.5
const MINING_IMPACT_AXIS_SCALE: float = 0.7
const MINING_IMPACT_PERPENDICULAR_SCALE: float = 1.25
const MINING_SHAKE_DURATION: float = 0.15
const MINING_SHAKE_STEPS: int = 5
const MINING_SHAKE_DISTANCE: float = 10.0
const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const DEFAULT_INFLUENCE_REACH: int = 3
const DEFAULT_SHOVEL_FIST_CHARGES: int = 1
const SHOVEL_FIST_PROJECTILE_RATIO: float = 0.45
const SHOVEL_FIST_PUSH_RATIO: float = 0.55
const SHOVEL_FIST_MAX_PUSH_TILES: int = 2
const MIN_MAP_MINES: int = 1
const MAX_MAP_MINES: int = 3
const MIN_SMALL_CRYSTALS_PER_MAP: int = 1
const MAX_SMALL_CRYSTALS_PER_MAP: int = 3
const CRYSTAL_POPUP_GROW_DURATION: float = 0.16
const CRYSTAL_POPUP_FADE_DURATION: float = 0.22
const CRYSTAL_POPUP_RISE_DISTANCE: float = 34.0
const EXIT_PING_INTERVAL: float = 1.2
const EXIT_PING_DURATION: float = 0.45
const EXIT_PING_BASE_SCALE: float = 0.82
const EXIT_PING_NARROW_SCALE: float = 1.21
const EXIT_PING_WIDE_SCALE: float = 1.72
const EXIT_PING_PADDING: float = 14.0
const EXIT_PING_BORDER_WIDTH: int = 10
const EXIT_PING_COLOR: Color = Color(1.0, 0.95, 0.55, 0.9)
const SHOVEL_FIST_HIGHLIGHT_FILL: Color = Color(1.0, 0.55, 0.15, 0.18)
const SHOVEL_FIST_HIGHLIGHT_BORDER: Color = Color(0.75, 0.35, 0.0, 0.55)
const PLAYER_INFLUENCE_HIGHLIGHT_FILL: Color = Color(0.2, 0.8, 0.35, 0.18)
const PLAYER_INFLUENCE_HIGHLIGHT_BORDER: Color = Color(0.1, 0.45, 0.18, 0.55)
const PLAYER_WALK_HIGHLIGHT_FILL: Color = Color(0.2, 0.45, 1.0, 0.35)
const PLAYER_WALK_HIGHLIGHT_BORDER: Color = Color(0.05, 0.2, 0.55, 0.9)
const PLAYER_ROCK_HIGHLIGHT_FILL: Color = Color(1.0, 0.85, 0.15, 0.4)
const PLAYER_ROCK_HIGHLIGHT_BORDER: Color = Color(0.6, 0.45, 0.0, 0.95)
const ENEMY_HIGHLIGHT_FILL: Color = Color(1.0, 0.0, 0.0, 0.5)
const ENEMY_HIGHLIGHT_BORDER: Color = Color(0.35, 0.0, 0.0, 0.95)
const RYE_FONT: FontFile = preload("res://Rye-Regular.ttf")
const EXIT_SCENE: PackedScene = preload("res://scenes/actors/Exit.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/Player.tscn")
const RED_GHOST_SCENE: PackedScene = preload("res://scenes/actors/RedGhost.tscn")
const ROCK_SCENE: PackedScene = preload("res://Rock.tscn")
const CRYSTAL_BIG_SCENE: PackedScene = preload("res://scenes/items/crystal_big.tscn")
const CRYSTAL_SMALL_1_SCENE: PackedScene = preload("res://scenes/items/crystal_small_1.tscn")
const CRYSTAL_SMALL_2_SCENE: PackedScene = preload("res://scenes/items/crystal_small_2.tscn")
const MINE_SCENE: PackedScene = preload("res://scenes/items/mine.tscn")
const MINE_EXPLOSION_SCENE: PackedScene = preload("res://scenes/effects/mine_explosion.tscn")
const SHOVEL_FIST_SCENE: PackedScene = preload("res://scenes/effects/shovel_fist.tscn")
const MAP_GENERATOR = preload("res://scripts/world/map_generator.gd")
const RED_GHOST_SYSTEM = preload("res://scripts/world/red_ghost_system.gd")
const MINE_SYSTEM = preload("res://scripts/world/mine_system.gd")
const SHOVEL_FIST_SYSTEM = preload("res://scripts/world/shovel_fist_system.gd")
const CRYSTAL_SYSTEM = preload("res://scripts/world/crystal_system.gd")
const SHOP_SYSTEM = preload("res://scripts/world/shop_system.gd")
const UPGRADE_SYSTEM = preload("res://scripts/world/upgrade_system.gd")

@onready var exit: Node2D = get_node_or_null("Exit") as Node2D
@onready var player: Node2D = get_node_or_null("Player") as Node2D
@onready var rocks: Node2D = $Rocks

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var map_state: Array = []
var rock_nodes: Dictionary = {}
var move_buttons: Dictionary = {}
var move_button_rects: Dictionary = {}
var start_cell: Vector2i = Vector2i.ZERO
var goal_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var red_ghosts: Array[Node2D] = []
var red_ghost_cells: Array[Vector2i] = []
var planned_red_ghost_turns: Array = []
var player_cell: Vector2i = Vector2i.ZERO
var active_move_tweens: Array[Tween] = []
var breathing_tweens: Dictionary = {}
var breathing_base_scales: Dictionary = {}
var breathing_base_positions: Dictionary = {}
var pending_mined_rocks: Array[Node2D] = []
var active_mine: Node2D = null
var active_mine_cell: Vector2i = INVALID_CELL
var collectible_mines: Dictionary = {}
var active_explosion_effects: Array[Node2D] = []
var active_shovel_fist_effects: Array[Node2D] = []
var pending_removed_ghosts: Array[Node2D] = []
var crystal_nodes: Dictionary = {}
var crystal_values: Dictionary = {}
var available_mines: int = 0
var max_shovel_fists: int = DEFAULT_SHOVEL_FIST_CHARGES
var available_shovel_fists: int = DEFAULT_SHOVEL_FIST_CHARGES
var crystal_total: int = 0
var press_started_ms: int = 0
var is_press_active: bool = false
var pressed_cell: Vector2i = INVALID_CELL
var influence_reach: int = DEFAULT_INFLUENCE_REACH
var current_level: int = 1
var is_game_over: bool = false
var is_turn_resolving: bool = false
var player_highlight_layer: CanvasLayer = null
var player_highlight_root: Control = null
var player_highlights: Array[Control] = []
var enemy_highlight_layer: CanvasLayer = null
var enemy_highlight_root: Control = null
var enemy_highlights: Array[Control] = []
var game_over_layer: CanvasLayer = null
var game_over_root: Control = null
var movement_button_layer: CanvasLayer = null
var crystal_ui_layer: CanvasLayer = null
var crystal_ui_root: Control = null
var crystal_label: Label = null
var mine_count_label: Label = null
var shovel_count_label: Label = null
var crystal_popup_root: Control = null
var active_crystal_popups: Array[Control] = []
var shop_layer: CanvasLayer = null
var shop_root: Control = null
var shop_crystal_label: Label = null
var shop_mine_button: Button = null
var shop_shovel_button: Button = null
var shop_upgrade_buttons: Array[Button] = []
var shop_continue_button: Button = null
var is_shop_open: bool = false
var current_shop_upgrades: Array[String] = []
var upgrade_levels: Dictionary = {}
var free_mines_remaining: int = 0
var free_moves_remaining: int = 0
var floor_ignored_mine_hits_remaining: int = 0
var floor_spiked_armor_hits_remaining: int = 0
var exit_ping_layer: CanvasLayer = null
var exit_ping_root: Control = null
var exit_ping_ring: Panel = null
var exit_ping_timer: Timer = null
var exit_ping_tween: Tween = null


func _ready() -> void:
	rng.randomize()
	_ensure_upgrade_state()
	_ensure_exit()
	_ensure_player()
	_ensure_player_highlight_layer()
	_ensure_enemy_highlight_layer()
	_ensure_exit_ping_ui()
	_ensure_game_over_ui()
	_ensure_crystal_ui()
	_ensure_shop_ui()
	_regenerate_level(false)
	_update_movement_buttons()


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
	return cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT


func _manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)


func _get_cardinal_directions() -> Array[Vector2i]:
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


func _spawn_rocks() -> void:
	for child in rocks.get_children():
		child.queue_free()
	rock_nodes.clear()

	var grid_layout: Dictionary = _get_grid_layout()
	var rock_scale_factor: float = grid_layout["rock_scale_factor"]
	var scaled_left_extent: float = grid_layout["scaled_left_extent"]
	var scaled_bottom_extent: float = grid_layout["scaled_bottom_extent"]
	var horizontal_step: float = grid_layout["horizontal_step"]
	var vertical_step: float = grid_layout["vertical_step"]
	var grid_left: float = grid_layout["grid_left"]
	var grid_bottom: float = grid_layout["grid_bottom"]

	for row_index in range(MAP_HEIGHT):
		for column_index in range(MAP_WIDTH):
			if not map_state[row_index][column_index]:
				continue

			var rock: Node2D = ROCK_SCENE.instantiate() as Node2D
			rock.scale = Vector2.ONE * rock_scale_factor
			rock.position = Vector2(
				grid_left + float(column_index) * horizontal_step - scaled_left_extent,
				grid_bottom - float(row_index) * vertical_step - scaled_bottom_extent
			)
			rocks.add_child(rock)
			rock_nodes[Vector2i(column_index, row_index)] = rock


func _ensure_player() -> void:
	if player != null:
		_start_breathing(player)
		return

	player = PLAYER_SCENE.instantiate() as Node2D

	if player == null:
		return

	player.name = "Player"
	player.z_index = 5
	add_child(player)
	_start_breathing(player)


func _ensure_player_highlight_layer() -> void:
	if player_highlight_layer != null:
		return

	player_highlight_layer = CanvasLayer.new()
	player_highlight_layer.name = "PlayerHighlights"
	add_child(player_highlight_layer)

	player_highlight_root = Control.new()
	player_highlight_root.name = "PlayerHighlightRoot"
	player_highlight_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_highlight_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_highlight_root.offset_left = 0.0
	player_highlight_root.offset_top = 0.0
	player_highlight_root.offset_right = 0.0
	player_highlight_root.offset_bottom = 0.0
	player_highlight_layer.add_child(player_highlight_root)


func _ensure_enemy_highlight_layer() -> void:
	if enemy_highlight_layer != null:
		return

	enemy_highlight_layer = CanvasLayer.new()
	enemy_highlight_layer.name = "EnemyHighlights"
	add_child(enemy_highlight_layer)

	enemy_highlight_root = Control.new()
	enemy_highlight_root.name = "EnemyHighlightRoot"
	enemy_highlight_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_highlight_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_highlight_root.offset_left = 0.0
	enemy_highlight_root.offset_top = 0.0
	enemy_highlight_root.offset_right = 0.0
	enemy_highlight_root.offset_bottom = 0.0
	enemy_highlight_layer.add_child(enemy_highlight_root)


func _ensure_exit_ping_ui() -> void:
	if exit_ping_layer != null:
		return

	exit_ping_layer = CanvasLayer.new()
	exit_ping_layer.name = "ExitPing"
	exit_ping_layer.layer = 4
	add_child(exit_ping_layer)

	exit_ping_root = Control.new()
	exit_ping_root.name = "ExitPingRoot"
	exit_ping_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exit_ping_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	exit_ping_root.offset_left = 0.0
	exit_ping_root.offset_top = 0.0
	exit_ping_root.offset_right = 0.0
	exit_ping_root.offset_bottom = 0.0
	exit_ping_layer.add_child(exit_ping_root)

	exit_ping_ring = Panel.new()
	exit_ping_ring.name = "ExitPingRing"
	exit_ping_ring.visible = false
	exit_ping_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exit_ping_ring.pivot_offset = Vector2.ZERO
	var ring_style: StyleBoxFlat = StyleBoxFlat.new()
	ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ring_style.border_color = EXIT_PING_COLOR
	ring_style.set_border_width_all(EXIT_PING_BORDER_WIDTH)
	ring_style.corner_radius_top_left = 999
	ring_style.corner_radius_top_right = 999
	ring_style.corner_radius_bottom_right = 999
	ring_style.corner_radius_bottom_left = 999
	exit_ping_ring.add_theme_stylebox_override("panel", ring_style)
	exit_ping_root.add_child(exit_ping_ring)

	exit_ping_timer = Timer.new()
	exit_ping_timer.name = "ExitPingTimer"
	exit_ping_timer.one_shot = false
	exit_ping_timer.wait_time = EXIT_PING_INTERVAL
	exit_ping_timer.timeout.connect(_on_exit_ping_timer_timeout)
	add_child(exit_ping_timer)


func _update_exit_ping_position() -> void:
	if exit_ping_ring == null or exit == null:
		return

	var grid_layout: Dictionary = _get_grid_layout()
	var exit_rect: Rect2 = _get_cell_highlight_rect(exit_cell, grid_layout).grow(EXIT_PING_PADDING)
	exit_ping_ring.position = exit_rect.position
	exit_ping_ring.size = exit_rect.size
	exit_ping_ring.pivot_offset = exit_rect.size / 2.0


func _trigger_exit_ping(is_wide: bool = false) -> void:
	if exit_ping_ring == null or is_shop_open or is_game_over:
		return

	_update_exit_ping_position()

	if exit_ping_tween != null and is_instance_valid(exit_ping_tween):
		exit_ping_tween.kill()

	var target_scale: float = EXIT_PING_WIDE_SCALE if is_wide else EXIT_PING_NARROW_SCALE
	exit_ping_ring.visible = true
	exit_ping_ring.modulate = EXIT_PING_COLOR
	exit_ping_ring.modulate.a = 0.9
	exit_ping_ring.scale = Vector2.ONE * EXIT_PING_BASE_SCALE
	exit_ping_tween = create_tween()
	exit_ping_tween.set_parallel(true)
	exit_ping_tween.tween_property(exit_ping_ring, "scale", Vector2.ONE * target_scale, EXIT_PING_DURATION)
	exit_ping_tween.tween_property(exit_ping_ring, "modulate:a", 0.0, EXIT_PING_DURATION)
	exit_ping_tween.finished.connect(_hide_exit_ping_ring)


func _hide_exit_ping_ring() -> void:
	if exit_ping_ring == null:
		return

	exit_ping_ring.visible = false
	exit_ping_ring.scale = Vector2.ONE
	exit_ping_ring.modulate = EXIT_PING_COLOR
	exit_ping_tween = null


func _start_exit_ping() -> void:
	_ensure_exit_ping_ui()

	if exit_ping_timer != null and exit_ping_timer.is_stopped():
		exit_ping_timer.start()

	_trigger_exit_ping(false)


func _stop_exit_ping() -> void:
	if exit_ping_timer != null:
		exit_ping_timer.stop()

	if exit_ping_tween != null and is_instance_valid(exit_ping_tween):
		exit_ping_tween.kill()
		exit_ping_tween = null

	if exit_ping_ring != null:
		exit_ping_ring.visible = false


func _on_exit_ping_timer_timeout() -> void:
	_trigger_exit_ping(false)


func _ensure_game_over_ui() -> void:
	if game_over_layer != null:
		return

	game_over_layer = CanvasLayer.new()
	game_over_layer.name = "GameOverUI"
	game_over_layer.layer = 10
	add_child(game_over_layer)

	game_over_root = Control.new()
	game_over_root.name = "GameOverRoot"
	game_over_root.visible = false
	game_over_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_root.offset_left = 0.0
	game_over_root.offset_top = 0.0
	game_over_root.offset_right = 0.0
	game_over_root.offset_bottom = 0.0
	game_over_layer.add_child(game_over_root)

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.72)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0
	game_over_root.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	game_over_root.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title: Label = Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", RYE_FONT)
	title.add_theme_font_size_override("font_size", 80)
	column.add_child(title)

	var retry_button: Button = Button.new()
	retry_button.text = "Retry"
	retry_button.custom_minimum_size = Vector2(320.0, 120.0)
	retry_button.add_theme_font_override("font", RYE_FONT)
	retry_button.add_theme_font_size_override("font_size", 32)
	retry_button.pressed.connect(_on_retry_pressed)
	column.add_child(retry_button)


func _ensure_crystal_ui() -> void:
	CRYSTAL_SYSTEM.ensure_crystal_ui(self)


func _ensure_upgrade_state() -> void:
	UPGRADE_SYSTEM.ensure_upgrade_state(self)


func _update_crystal_label() -> void:
	CRYSTAL_SYSTEM.update_crystal_label(self)


func _update_resource_labels() -> void:
	CRYSTAL_SYSTEM.update_resource_labels(self)
	SHOP_SYSTEM.update_shop_ui(self)


func _get_discounted_shop_cost(base_cost: int) -> int:
	return UPGRADE_SYSTEM.get_discounted_cost(self, base_cost)


func _get_upgrade_level(upgrade_id: String) -> int:
	return UPGRADE_SYSTEM.get_upgrade_level(self, upgrade_id)


func _get_shop_mine_cost() -> int:
	return _get_discounted_shop_cost(2)


func _get_shop_shovel_cost() -> int:
	return _get_discounted_shop_cost(1)


func _roll_shop_upgrades() -> void:
	UPGRADE_SYSTEM.roll_shop_upgrades(self)


func _get_shop_upgrade_button_text(offer_index: int) -> String:
	return UPGRADE_SYSTEM.get_offer_text(self, offer_index)


func _is_shop_upgrade_disabled(offer_index: int) -> bool:
	return UPGRADE_SYSTEM.is_offer_disabled(self, offer_index)


func _buy_shop_upgrade(offer_index: int) -> void:
	UPGRADE_SYSTEM.buy_shop_upgrade(self, offer_index)


func _reset_turn_bonus_counters() -> void:
	UPGRADE_SYSTEM.reset_turn_bonus_counters(self)


func _reset_floor_upgrade_state() -> void:
	UPGRADE_SYSTEM.reset_floor_upgrade_state(self)


func _consume_free_move_charge() -> bool:
	return UPGRADE_SYSTEM.consume_free_move_charge(self)


func _consume_free_mine_charge() -> bool:
	return UPGRADE_SYSTEM.consume_free_mine_charge(self)


func _get_mine_blast_radius() -> int:
	return UPGRADE_SYSTEM.get_mine_blast_radius(self)


func _try_ignore_mine_damage() -> bool:
	return UPGRADE_SYSTEM.try_ignore_mine_damage(self)


func _get_shovel_push_distance() -> int:
	return UPGRADE_SYSTEM.get_shovel_push_distance(self)


func _resolve_spiked_armor_collisions(colliding_indices: Array[int]) -> bool:
	return UPGRADE_SYSTEM.resolve_spiked_armor_collisions(self, colliding_indices)


func _clear_crystals() -> void:
	CRYSTAL_SYSTEM.clear_crystals(self)


func _spawn_map_crystals() -> void:
	CRYSTAL_SYSTEM.spawn_map_crystals(self)


func _has_crystal_at_cell(cell: Vector2i) -> bool:
	return CRYSTAL_SYSTEM.has_crystal_at_cell(self, cell)


func _collect_crystal_at_cell(cell: Vector2i) -> int:
	return CRYSTAL_SYSTEM.collect_crystal_at_cell(self, cell)


func _ensure_shop_ui() -> void:
	SHOP_SYSTEM.ensure_shop_ui(self)


func _open_shop() -> void:
	_stop_exit_ping()
	_roll_shop_upgrades()
	is_shop_open = true
	SHOP_SYSTEM.open_shop(self)


func _close_shop() -> void:
	SHOP_SYSTEM.close_shop(self)
	is_shop_open = false


func _buy_shop_mine() -> void:
	SHOP_SYSTEM.buy_mine(self)


func _buy_shop_shovel() -> void:
	SHOP_SYSTEM.buy_shovel(self)


func _on_shop_upgrade_pressed(offer_index: int) -> void:
	_buy_shop_upgrade(offer_index)


func _on_shop_buy_mine_pressed() -> void:
	_buy_shop_mine()


func _on_shop_buy_shovel_pressed() -> void:
	_buy_shop_shovel()


func _on_shop_continue_pressed() -> void:
	_close_shop()
	_regenerate_level(true)


func _ensure_exit() -> void:
	if exit != null:
		return

	exit = EXIT_SCENE.instantiate() as Node2D

	if exit == null:
		return

	exit.name = "Exit"
	exit.z_index = 3
	add_child(exit)


func _place_player() -> void:
	if player == null:
		return

	var spawn_cell: Vector2i = _get_player_spawn_cell()
	_move_player_to_cell(spawn_cell)
	_start_breathing(player)


func _spawn_red_ghosts() -> void:
	RED_GHOST_SYSTEM.spawn_red_ghosts(self)


func _clear_red_ghosts() -> void:
	RED_GHOST_SYSTEM.clear_red_ghosts(self)


func _start_breathing(node: Node2D) -> void:
	if node == null:
		return

	var breathing_target: Node2D = _get_breathing_target(node)

	if breathing_target == null:
		return

	_clear_breathing_tween(node)
	var base_scale: Vector2 = breathing_target.scale
	var base_position: Vector2 = breathing_target.position
	var position_offset: Vector2 = _get_breathing_position_offset(node)
	breathing_base_scales[breathing_target] = base_scale
	breathing_base_positions[breathing_target] = base_position
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(
		breathing_target,
		"scale",
		Vector2(base_scale.x * BREATH_SCALE_X, base_scale.y * BREATH_SCALE_Y),
		BREATH_HALF_CYCLE_DURATION
	)
	if position_offset != Vector2.ZERO:
		tween.parallel().tween_property(breathing_target, "position", base_position + position_offset, BREATH_HALF_CYCLE_DURATION)
	tween.tween_property(breathing_target, "scale", base_scale, BREATH_HALF_CYCLE_DURATION)
	if position_offset != Vector2.ZERO:
		tween.parallel().tween_property(breathing_target, "position", base_position, BREATH_HALF_CYCLE_DURATION)
	breathing_tweens[breathing_target] = tween


func _clear_breathing_tween(node: Node2D, reset_visual: bool = true) -> void:
	if node == null:
		return

	var breathing_target: Node2D = _get_breathing_target(node)

	if breathing_target == null:
		return

	if breathing_tweens.has(breathing_target):
		var tween: Tween = breathing_tweens[breathing_target] as Tween

		if tween != null and is_instance_valid(tween):
			tween.kill()

		breathing_tweens.erase(breathing_target)

	if reset_visual and breathing_base_scales.has(breathing_target):
		breathing_target.scale = breathing_base_scales[breathing_target]

	if reset_visual and breathing_base_positions.has(breathing_target):
		breathing_target.position = breathing_base_positions[breathing_target]

	if breathing_base_scales.has(breathing_target):
		breathing_base_scales.erase(breathing_target)

	if breathing_base_positions.has(breathing_target):
		breathing_base_positions.erase(breathing_target)


func _get_breathing_target(node: Node2D) -> Node2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child as Node2D

	return node


func _get_breathing_position_offset(node: Node2D) -> Vector2:
	if node == player:
		return Vector2(PLAYER_BREATH_SHIFT_X, 0.0)

	return Vector2.ZERO


func _get_visual_base_scale(node: Node2D) -> Vector2:
	var breathing_target: Node2D = _get_breathing_target(node)

	if breathing_target == null:
		return Vector2.ONE

	if breathing_base_scales.has(breathing_target):
		return breathing_base_scales[breathing_target]

	return breathing_target.scale


func _get_visual_base_position(node: Node2D) -> Vector2:
	var breathing_target: Node2D = _get_breathing_target(node)

	if breathing_target == null:
		return Vector2.ZERO

	if breathing_base_positions.has(breathing_target):
		return breathing_base_positions[breathing_target]

	return breathing_target.position


func _create_player_move_visual_tween(direction: Vector2i, duration: float) -> Tween:
	if player == null:
		return null

	return _create_move_visual_tween(player, direction, duration, PLAYER_MOVE_STRETCH_SCALE)


func _create_move_visual_tween(node: Node2D, direction: Vector2i, duration: float, stretch_scale_factor: float) -> Tween:
	if node == null:
		return null

	var breathing_target: Node2D = _get_breathing_target(node)

	if breathing_target == null:
		return null

	var base_scale: Vector2 = _get_visual_base_scale(node)
	var base_position: Vector2 = _get_visual_base_position(node)
	_clear_breathing_tween(node, false)
	var stretch_scale: Vector2 = base_scale

	if direction.x != 0:
		stretch_scale.x = base_scale.x * stretch_scale_factor
	else:
		stretch_scale.y = base_scale.y * stretch_scale_factor

	var tween: Tween = create_tween()
	active_move_tweens.append(tween)
	tween.tween_property(breathing_target, "scale", stretch_scale, duration * 0.5)
	tween.tween_property(breathing_target, "scale", base_scale, duration * 0.5)
	tween.parallel().tween_property(breathing_target, "position", base_position, duration * 0.5)
	return tween


func _place_exit() -> void:
	if exit == null:
		return

	exit_cell = _get_exit_spawn_cell()
	var grid_layout: Dictionary = _get_grid_layout()
	var cell_center: Vector2 = _get_cell_center_position(exit_cell, grid_layout)
	var exit_bounds: Rect2 = _get_exit_visual_bounds()

	exit.position = cell_center - exit_bounds.get_center()
	_update_exit_ping_position()


func _move_player_to_cell(cell: Vector2i) -> void:
	if player == null:
		return

	player_cell = cell
	player.position = _get_player_target_position(cell, _get_grid_layout())
	_update_movement_buttons()


func _animate_player_to_cell(cell: Vector2i, duration: float) -> void:
	if player == null:
		return

	player_cell = cell
	var target_position: Vector2 = _get_player_target_position(cell, _get_grid_layout())
	await _animate_node_to_position(player, target_position, duration)
	_update_movement_buttons()


func _get_player_target_position(cell: Vector2i, grid_layout: Dictionary) -> Vector2:
	if player == null:
		return _get_cell_center_position(cell, grid_layout)

	var sprite: Sprite2D = player.get_node_or_null("Player") as Sprite2D

	if sprite == null:
		return _get_cell_center_position(cell, grid_layout)

	return _get_cell_center_position(cell, grid_layout) - sprite.position


func _move_red_ghost_to_cell(ghost_index: int, cell: Vector2i) -> void:
	if ghost_index < 0 or ghost_index >= red_ghosts.size():
		return

	var ghost: Node2D = red_ghosts[ghost_index]

	if ghost == null:
		return

	red_ghost_cells[ghost_index] = cell
	ghost.position = _get_cell_center_position(cell, _get_grid_layout())


func _animate_red_ghost_to_cell(ghost_index: int, cell: Vector2i, duration: float) -> void:
	if ghost_index < 0 or ghost_index >= red_ghosts.size():
		return

	var ghost: Node2D = red_ghosts[ghost_index]

	if ghost == null:
		return

	red_ghost_cells[ghost_index] = cell
	var target_position: Vector2 = _get_cell_center_position(cell, _get_grid_layout())
	await _animate_node_to_position(ghost, target_position, duration)


func _animate_node_to_position(node: Node2D, target_position: Vector2, duration: float) -> void:
	if node == null:
		return

	if duration <= 0.0:
		node.position = target_position
		return

	var tween: Tween = create_tween()
	tween.tween_property(node, "position", target_position, duration)
	await tween.finished


func _animate_removed_ghost(ghost: Node2D) -> void:
	if ghost == null or not is_instance_valid(ghost):
		return

	var visual_target: Node2D = _get_breathing_target(ghost)

	if visual_target == null:
		visual_target = ghost

	_clear_breathing_tween(ghost)
	ghost.z_index = 7
	ghost.modulate.a = 1.0
	visual_target.scale = _get_visual_base_scale(ghost)
	var base_scale: Vector2 = visual_target.scale
	var base_rotation: float = ghost.rotation
	var total_duration: float = GHOST_DEATH_EXPAND_DURATION + GHOST_DEATH_SHRINK_DURATION
	var spin_tween: Tween = create_tween()
	spin_tween.set_trans(Tween.TRANS_LINEAR)
	spin_tween.set_ease(Tween.EASE_IN_OUT)
	spin_tween.tween_property(ghost, "rotation", base_rotation + GHOST_DEATH_SPIN_RADIANS, total_duration)
	var scale_tween: Tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(visual_target, "scale", base_scale * GHOST_DEATH_EXPAND_SCALE, GHOST_DEATH_EXPAND_DURATION)
	scale_tween.set_trans(Tween.TRANS_QUAD)
	scale_tween.set_ease(Tween.EASE_IN)
	scale_tween.tween_property(visual_target, "scale", Vector2.ZERO, GHOST_DEATH_SHRINK_DURATION)
	scale_tween.parallel().tween_property(ghost, "modulate:a", 0.0, GHOST_DEATH_SHRINK_DURATION)
	scale_tween.finished.connect(Callable(self, "_finalize_removed_ghost_animation").bind(ghost))


func _finalize_removed_ghost_animation(ghost: Node2D) -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_shop_open:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch

		if touch_event.pressed:
			_begin_press_at_position(touch_event.position)
		else:
			if await _end_press_at_position(touch_event.position):
				get_viewport().set_input_as_handled()

		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_press_at_position(mouse_event.position)
			else:
				if await _end_press_at_position(mouse_event.position):
					get_viewport().set_input_as_handled()

		return


func _begin_press_at_position(screen_position: Vector2) -> void:
	if is_turn_resolving:
		return

	is_press_active = true
	press_started_ms = Time.get_ticks_msec()
	var touched_cell: Variant = _get_touched_cell(screen_position)

	if touched_cell == null:
		pressed_cell = INVALID_CELL
		return

	pressed_cell = touched_cell as Vector2i


func _end_press_at_position(screen_position: Vector2) -> bool:
	if not is_press_active:
		return false

	is_press_active = false
	var started_cell: Vector2i = pressed_cell
	pressed_cell = INVALID_CELL

	if started_cell == INVALID_CELL or is_turn_resolving:
		return false

	var released_cell_variant: Variant = _get_touched_cell(screen_position)

	if released_cell_variant != null:
		var released_cell: Vector2i = released_cell_variant as Vector2i

		if released_cell != started_cell:
			return false

	var held_duration: float = float(Time.get_ticks_msec() - press_started_ms) / 1000.0

	if held_duration >= LONG_PRESS_DURATION:
		return await _handle_long_press_on_cell(started_cell)

	return await _handle_tap_on_cell(started_cell)


func _handle_tap_on_cell(cell: Vector2i) -> bool:
	if _has_any_mine_at_cell(cell) and _is_cell_in_influence_reach(cell):
		await _take_back_mine_at_cell(cell)
		return true

	var move_direction: Vector2i = _get_move_direction_for_cell(cell)

	if move_direction != Vector2i.ZERO:
		await _attempt_player_move(move_direction)
		return true

	if cell == player_cell:
		await _attempt_player_move(Vector2i.ZERO)
		return true

	return false


func _handle_long_press_on_cell(cell: Vector2i) -> bool:
	var shovel_target_index: int = _get_shovel_fist_target_index(cell)

	if shovel_target_index != -1:
		await _use_shovel_fist_on_ghost(shovel_target_index)
		return true

	if _can_place_mine_at_cell(cell):
		await _place_active_mine(cell)
		return true

	return false


func _get_move_direction_for_cell(cell: Vector2i) -> Vector2i:
	var delta: Vector2i = cell - player_cell

	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO

	if delta.x < 0:
		return Vector2i.LEFT
	if delta.x > 0:
		return Vector2i.RIGHT
	if delta.y < 0:
		return Vector2i(0, -1)
	if delta.y > 0:
		return Vector2i(0, 1)

	return Vector2i.ZERO


func _can_place_mine_at_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.can_place_mine_at_cell(self, cell)


func _has_shovel_fist_charge() -> bool:
	return SHOVEL_FIST_SYSTEM.has_shovel_fist_charge(self)


func _has_influence_action_available() -> bool:
	return MINE_SYSTEM.has_influence_action_available(self)


func _get_shovel_fist_target_index(cell: Vector2i) -> int:
	return SHOVEL_FIST_SYSTEM.get_shovel_fist_target_index(self, cell)


func _is_ghost_eligible_for_shovel_fist(ghost_index: int) -> bool:
	return SHOVEL_FIST_SYSTEM.is_ghost_eligible_for_shovel_fist(self, ghost_index)


func _is_enemy_cell_eligible_for_shovel_fist(cell: Vector2i) -> bool:
	return SHOVEL_FIST_SYSTEM.is_enemy_cell_eligible_for_shovel_fist(self, cell)


func _has_clear_line_of_effect(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return SHOVEL_FIST_SYSTEM.has_clear_line_of_effect(self, from_cell, to_cell)


func _get_line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	return SHOVEL_FIST_SYSTEM.get_line_cells(self, from_cell, to_cell)


func _use_shovel_fist_on_ghost(ghost_index: int) -> void:
	await SHOVEL_FIST_SYSTEM.use_shovel_fist_on_ghost(self, ghost_index)


func _animate_shovel_fist_attack(ghost_index: int, duration: float) -> void:
	SHOVEL_FIST_SYSTEM.animate_shovel_fist_attack(self, ghost_index, duration)


func _on_shovel_wall_impact(ghost: Node2D) -> void:
	SHOVEL_FIST_SYSTEM.handle_shovel_wall_impact(self, ghost)


func _on_shovel_collision_impact(incoming_ghost: Node2D, blocker_ghost: Node2D, push_direction: Vector2i, push_duration: float) -> void:
	SHOVEL_FIST_SYSTEM.handle_shovel_collision_impact(self, incoming_ghost, blocker_ghost, push_direction, push_duration)


func _on_shovel_mine_collision(ghost: Node2D, detonated_mine_cell: Vector2i) -> void:
	SHOVEL_FIST_SYSTEM.handle_shovel_mine_collision(self, ghost, detonated_mine_cell)


func _get_shovel_fist_push_direction(target_cell: Vector2i) -> Vector2i:
	return SHOVEL_FIST_SYSTEM.get_shovel_fist_push_direction(self, target_cell)


func _get_shovel_fist_push_path(start_cell: Vector2i) -> Array[Vector2i]:
	return SHOVEL_FIST_SYSTEM.get_shovel_fist_push_path(self, start_cell)


func _shovel_fist_hits_wall_or_edge(start_cell: Vector2i) -> bool:
	return SHOVEL_FIST_SYSTEM.shovel_fist_hits_wall_or_edge(self, start_cell)


func _clear_shovel_fist_effects() -> void:
	SHOVEL_FIST_SYSTEM.clear_shovel_fist_effects(self)


func _finalize_pending_removed_ghosts() -> void:
	for ghost in pending_removed_ghosts:
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()

	pending_removed_ghosts.clear()


func _detach_red_ghost_at_index(ghost_index: int) -> Node2D:
	return RED_GHOST_SYSTEM.detach_red_ghost_at_index(self, ghost_index)


func _is_cell_in_influence_reach(cell: Vector2i) -> bool:
	return MINE_SYSTEM.is_cell_in_influence_reach(self, cell)


func _is_influence_dirt_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.is_influence_dirt_cell(self, cell)


func _has_mine_at_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.has_mine_at_cell(self, cell)


func _has_armed_mine_at_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.has_armed_mine_at_cell(self, cell)


func _has_collectible_mine_at_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.has_collectible_mine_at_cell(self, cell)


func _has_any_mine_at_cell(cell: Vector2i) -> bool:
	return MINE_SYSTEM.has_any_mine_at_cell(self, cell)


func _place_active_mine(cell: Vector2i) -> void:
	await MINE_SYSTEM.place_active_mine(self, cell)


func _take_back_active_mine() -> void:
	await MINE_SYSTEM.take_back_active_mine(self)


func _take_back_mine_at_cell(cell: Vector2i) -> void:
	await MINE_SYSTEM.take_back_mine_at_cell(self, cell)


func _spawn_active_mine(cell: Vector2i) -> void:
	MINE_SYSTEM.spawn_active_mine(self, cell)


func _clear_active_mine(refund: bool) -> void:
	MINE_SYSTEM.clear_active_mine(self, refund)


func _clear_collectible_mines() -> void:
	MINE_SYSTEM.clear_collectible_mines(self)


func _spawn_collectible_mines() -> void:
	MINE_SYSTEM.spawn_collectible_mines(self)


func _place_collectible_mine(cell: Vector2i) -> void:
	MINE_SYSTEM.place_collectible_mine(self, cell)


func _pick_up_collectible_mine(cell: Vector2i) -> void:
	MINE_SYSTEM.pick_up_collectible_mine(self, cell)


func _clear_collectible_mine_at_cell(cell: Vector2i) -> void:
	MINE_SYSTEM.clear_collectible_mine_at_cell(self, cell)


func _spawn_mine_explosion_effect(cell: Vector2i, duration: float) -> void:
	MINE_SYSTEM.spawn_mine_explosion_effect(self, cell, duration)


func _clear_explosion_effects() -> void:
	MINE_SYSTEM.clear_explosion_effects(self)


func _get_blast_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return MINE_SYSTEM.get_blast_cells(self, center_cell)


func _trigger_mine_explosion(cell: Vector2i, duration: float) -> Array[int]:
	return MINE_SYSTEM.trigger_mine_explosion(self, cell, duration)


func _does_mine_explosion_hit_player(cell: Vector2i) -> bool:
	return MINE_SYSTEM.does_mine_explosion_hit_player(self, cell)


func _destroy_rock_from_explosion(cell: Vector2i) -> void:
	MINE_SYSTEM.destroy_rock_from_explosion(self, cell)


func _get_red_ghost_indices_in_cells(cells: Array[Vector2i]) -> Array[int]:
	return RED_GHOST_SYSTEM.get_red_ghost_indices_in_cells(self, cells)


func _remove_red_ghosts_by_indices(indices: Array[int]) -> void:
	RED_GHOST_SYSTEM.remove_red_ghosts_by_indices(self, indices)


func _get_player_spawn_cell() -> Vector2i:
	var open_cells: Array[Vector2i] = []
	var bottom_row_index: int = MAP_HEIGHT - 1

	for column_index in range(MAP_WIDTH):
		var cell: Vector2i = Vector2i(column_index, bottom_row_index)

		if not _is_cell_occupied(cell):
			open_cells.append(cell)

	if not open_cells.is_empty():
		return open_cells[rng.randi_range(0, open_cells.size() - 1)]

	return start_cell


func _get_red_ghost_spawn_cells(ghost_count: int) -> Array[Vector2i]:
	return RED_GHOST_SYSTEM.get_red_ghost_spawn_cells(self, ghost_count)


func _get_exit_spawn_cell() -> Vector2i:
	var open_cells: Array[Vector2i] = []
	var top_row_index: int = 0

	for column_index in range(MAP_WIDTH):
		var cell: Vector2i = Vector2i(column_index, top_row_index)

		if not _is_cell_occupied(cell):
			open_cells.append(cell)

	if not open_cells.is_empty():
		return open_cells[rng.randi_range(0, open_cells.size() - 1)]

	return goal_cell


func _get_cell_anchor_position(cell: Vector2i, grid_layout: Dictionary) -> Vector2:
	return Vector2(
		grid_layout["grid_left"] + float(cell.x) * grid_layout["horizontal_step"],
		grid_layout["grid_bottom"] - float(cell.y) * grid_layout["vertical_step"]
	)


func _get_cell_center_position(cell: Vector2i, grid_layout: Dictionary) -> Vector2:
	var tile_size: Vector2 = grid_layout["scaled_rock_size"]

	return Vector2(
		grid_layout["grid_left"] + float(cell.x) * grid_layout["horizontal_step"] + tile_size.x / 2.0,
		grid_layout["grid_bottom"] - float(cell.y) * grid_layout["vertical_step"] - tile_size.y / 2.0
	)


func _get_cell_highlight_rect(cell: Vector2i, grid_layout: Dictionary) -> Rect2:
	return Rect2(
		Vector2(
			grid_layout["grid_left"] + float(cell.x) * grid_layout["horizontal_step"],
			grid_layout["grid_bottom"] - float(cell.y + 1) * grid_layout["vertical_step"]
		),
		Vector2(grid_layout["horizontal_step"], grid_layout["vertical_step"])
	)


func _get_touch_move_direction(screen_position: Vector2) -> Vector2i:
	if player == null:
		return Vector2i.ZERO

	var touched_cell: Variant = _get_touched_cell(screen_position)

	if touched_cell == null:
		return Vector2i.ZERO

	var target_cell: Vector2i = touched_cell as Vector2i
	var delta: Vector2i = target_cell - player_cell

	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO

	if delta.x != 0:
		if delta.x < 0:
			return Vector2i.LEFT

		return Vector2i.RIGHT

	if delta.y < 0:
		return Vector2i(0, -1)

	return Vector2i(0, 1)


func _did_touch_player_cell(screen_position: Vector2) -> bool:
	var touched_cell: Variant = _get_touched_cell(screen_position)

	if touched_cell == null:
		return false

	return touched_cell == player_cell


func _get_touched_cell(screen_position: Vector2) -> Variant:
	var grid_layout: Dictionary = _get_grid_layout()

	for row_index in range(MAP_HEIGHT):
		for column_index in range(MAP_WIDTH):
			var cell: Vector2i = Vector2i(column_index, row_index)
			var rect: Rect2 = _get_cell_highlight_rect(cell, grid_layout)

			if rect.has_point(screen_position):
				return cell

	return null


func _ensure_movement_buttons() -> void:
	if movement_button_layer != null:
		return

	movement_button_layer = CanvasLayer.new()
	movement_button_layer.name = "MovementButtons"
	add_child(movement_button_layer)

	var button_specs: Array[Dictionary] = [
		{"name": "MoveUpButton", "text": "^", "direction": Vector2i(0, 1)},
		{"name": "MoveDownButton", "text": "v", "direction": Vector2i(0, -1)},
		{"name": "MoveLeftButton", "text": "<", "direction": Vector2i.LEFT},
		{"name": "MoveRightButton", "text": ">", "direction": Vector2i.RIGHT},
	]

	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = Color.WHITE
	button_style.border_color = Color.BLACK
	button_style.set_border_width_all(2)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8

	for button_spec in button_specs:
		var button: Button = Button.new()
		button.name = button_spec["name"]
		button.text = button_spec["text"]
		button.add_theme_font_override("font", RYE_FONT)
		button.add_theme_font_size_override("font_size", 32)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_style.duplicate())
		button.add_theme_stylebox_override("pressed", button_style.duplicate())
		button.add_theme_stylebox_override("disabled", button_style.duplicate())
		button.add_theme_color_override("font_color", Color.BLACK)
		button.add_theme_color_override("font_hover_color", Color.BLACK)
		button.add_theme_color_override("font_pressed_color", Color.BLACK)
		button.add_theme_color_override("font_disabled_color", Color(0.2, 0.2, 0.2, 0.75))
		movement_button_layer.add_child(button)
		move_buttons[button_spec["direction"]] = button


func _update_movement_buttons() -> void:
	if player == null:
		return

	_update_exit_ping_position()

	if movement_button_layer != null:
		movement_button_layer.visible = false

	_show_player_move_highlights()

	if movement_button_layer == null:
		return

	var grid_layout: Dictionary = _get_grid_layout()
	var player_bounds: Rect2 = _get_player_visual_bounds()
	var horizontal_step: float = grid_layout["horizontal_step"]
	var vertical_step: float = grid_layout["vertical_step"]
	var horizontal_button_size: Vector2 = Vector2(horizontal_step * MOVE_BUTTON_LENGTH_RATIO, MOVE_BUTTON_THICKNESS)
	var vertical_button_size: Vector2 = Vector2(MOVE_BUTTON_THICKNESS, vertical_step * MOVE_BUTTON_LENGTH_RATIO)
	var player_center: Vector2 = player_bounds.get_center()
	var left_edge: float = player_bounds.position.x
	var right_edge: float = player_bounds.end.x
	var top_edge: float = player_bounds.position.y
	var bottom_edge: float = player_bounds.end.y
	var button_data: Dictionary = {
		Vector2i(0, 1): {
			"size": horizontal_button_size,
			"position": Vector2(
				player_center.x - horizontal_button_size.x / 2.0,
				top_edge - MOVE_BUTTON_PLAYER_GAP - horizontal_button_size.y
			),
		},
		Vector2i(0, -1): {
			"size": horizontal_button_size,
			"position": Vector2(
				player_center.x - horizontal_button_size.x / 2.0,
				bottom_edge + MOVE_BUTTON_PLAYER_GAP
			),
		},
		Vector2i.LEFT: {
			"size": vertical_button_size,
			"position": Vector2(
				left_edge - MOVE_BUTTON_PLAYER_GAP - vertical_button_size.x,
				player_center.y - vertical_button_size.y / 2.0
			),
		},
		Vector2i.RIGHT: {
			"size": vertical_button_size,
			"position": Vector2(
				right_edge + MOVE_BUTTON_PLAYER_GAP,
				player_center.y - vertical_button_size.y / 2.0
			),
		},
	}

	for direction in button_data.keys():
		var button: Button = move_buttons[direction]
		var data: Dictionary = button_data[direction]
		var button_size: Vector2 = data["size"]
		var button_position: Vector2 = data["position"]
		button.size = button_size
		button.pivot_offset = button_size / 2.0
		button.position = button_position
		button.disabled = is_turn_resolving or not _is_in_bounds(player_cell + direction)
		move_button_rects[direction] = Rect2(button_position, button_size)


func _get_player_visual_bounds() -> Rect2:
	var sprite: Sprite2D = player.get_node_or_null("Player") as Sprite2D

	if sprite == null or sprite.texture == null:
		return Rect2(player.global_position - Vector2.ONE * 16.0, Vector2.ONE * 32.0)

	var sprite_size: Vector2 = sprite.texture.get_size() * sprite.scale
	var top_left: Vector2 = player.global_position + sprite.position - sprite_size / 2.0

	return Rect2(top_left, sprite_size)


func _get_exit_visual_bounds() -> Rect2:
	var sprite: Sprite2D = exit.get_node_or_null("Exit") as Sprite2D

	if sprite == null or sprite.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ONE)

	var sprite_size: Vector2 = sprite.texture.get_size() * sprite.scale
	var top_left: Vector2 = sprite.position - sprite_size / 2.0

	return Rect2(top_left, sprite_size)


func _show_enemy_highlights(cells: Array[Vector2i]) -> void:
	RED_GHOST_SYSTEM.show_enemy_highlights(self, cells)


func _show_player_move_highlights() -> void:
	_clear_player_move_highlights()

	if player_highlight_root == null or player == null:
		return

	var grid_layout: Dictionary = _get_grid_layout()

	if _has_influence_action_available():
		for row_index in range(MAP_HEIGHT):
			for column_index in range(MAP_WIDTH):
				var influence_cell: Vector2i = Vector2i(column_index, row_index)

				if not _is_influence_dirt_cell(influence_cell):
					continue

				var influence_panel: Panel = Panel.new()
				var influence_style: StyleBoxFlat = StyleBoxFlat.new()
				influence_style.bg_color = PLAYER_INFLUENCE_HIGHLIGHT_FILL
				influence_style.border_color = PLAYER_INFLUENCE_HIGHLIGHT_BORDER
				influence_style.set_border_width_all(2)
				influence_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				influence_panel.add_theme_stylebox_override("panel", influence_style)
				var influence_rect: Rect2 = _get_cell_highlight_rect(influence_cell, grid_layout)
				influence_panel.position = influence_rect.position
				influence_panel.size = influence_rect.size
				player_highlight_root.add_child(influence_panel)
				player_highlights.append(influence_panel)

	if _has_shovel_fist_charge():
		for ghost_cell in red_ghost_cells:
			if not _is_enemy_cell_eligible_for_shovel_fist(ghost_cell):
				continue

			var target_panel: Panel = Panel.new()
			var target_style: StyleBoxFlat = StyleBoxFlat.new()
			target_style.bg_color = SHOVEL_FIST_HIGHLIGHT_FILL
			target_style.border_color = SHOVEL_FIST_HIGHLIGHT_BORDER
			target_style.set_border_width_all(2)
			target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			target_panel.add_theme_stylebox_override("panel", target_style)
			var target_rect: Rect2 = _get_cell_highlight_rect(ghost_cell, grid_layout)
			target_panel.position = target_rect.position
			target_panel.size = target_rect.size
			player_highlight_root.add_child(target_panel)
			player_highlights.append(target_panel)

	for direction in _get_cardinal_directions():
		var cell: Vector2i = player_cell + direction

		if not _is_in_bounds(cell):
			continue

		var panel: Panel = Panel.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()

		if _is_cell_occupied(cell):
			style.bg_color = PLAYER_ROCK_HIGHLIGHT_FILL
			style.border_color = PLAYER_ROCK_HIGHLIGHT_BORDER
		else:
			style.bg_color = PLAYER_WALK_HIGHLIGHT_FILL
			style.border_color = PLAYER_WALK_HIGHLIGHT_BORDER

		style.set_border_width_all(3)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		var rect: Rect2 = _get_cell_highlight_rect(cell, grid_layout)
		panel.position = rect.position
		panel.size = rect.size
		player_highlight_root.add_child(panel)
		player_highlights.append(panel)


func _clear_player_move_highlights() -> void:
	for highlight in player_highlights:
		if highlight != null:
			highlight.queue_free()

	player_highlights.clear()


func _clear_enemy_highlights() -> void:
	RED_GHOST_SYSTEM.clear_enemy_highlights(self)


func _attempt_player_move(direction: Vector2i) -> void:
	if is_turn_resolving or is_game_over:
		return

	if direction == Vector2i.ZERO:
		is_turn_resolving = true
		_clear_player_move_highlights()
		_clear_enemy_highlights()
		await _run_turn(player_cell, false)
		if is_game_over:
			return
		is_turn_resolving = false
		_update_movement_buttons()
		return

	var target_cell: Vector2i = player_cell + direction

	if not _is_in_bounds(target_cell):
		return

	is_turn_resolving = true
	_clear_player_move_highlights()
	_clear_enemy_highlights()
	_update_movement_buttons()

	if _is_cell_occupied(target_cell):
		_create_player_mining_animation(target_cell, PLAYER_MOVE_DURATION)
		_destroy_rock(target_cell, PLAYER_MOVE_DURATION, PLAYER_MOVE_DURATION * MINING_LUNGE_RATIO)
		if _consume_free_mine_charge():
			await _run_turn_step(player_cell, false, {}, PLAYER_MOVE_DURATION)
			if is_game_over:
				return
			_show_existing_enemy_turn_preview()
			is_turn_resolving = false
			_update_movement_buttons()
			return
		await _run_turn(player_cell, false, PLAYER_MOVE_DURATION)
		if is_game_over:
			return
		is_turn_resolving = false
		_update_movement_buttons()
		return

	if _consume_free_move_charge():
		await _run_turn_step(target_cell, true, {})
		if is_game_over:
			return
		if player_cell == exit_cell:
			_open_shop()
			return
		_show_existing_enemy_turn_preview()
		is_turn_resolving = false
		_update_movement_buttons()
		return

	await _run_turn(target_cell, true)
	if is_game_over:
		return
	if is_shop_open:
		return
	is_turn_resolving = false
	_update_movement_buttons()


func _destroy_rock(cell: Vector2i, duration: float = PLAYER_MOVE_DURATION, delay: float = 0.0) -> void:
	if not _is_cell_occupied(cell):
		return

	_set_cell_occupied(cell, false)

	if rock_nodes.has(cell):
		var rock: Node2D = rock_nodes[cell] as Node2D
		rock_nodes.erase(cell)

		if rock != null:
			_animate_mined_rock(rock, duration, delay)


func _create_player_mining_animation(target_cell: Vector2i, duration: float) -> void:
	if player == null:
		return

	var breathing_target: Node2D = _get_breathing_target(player)

	if breathing_target == null:
		return

	var current_visual_scale: Vector2 = breathing_target.scale
	var current_visual_position: Vector2 = breathing_target.position
	var base_visual_scale: Vector2 = _get_visual_base_scale(player)
	var base_visual_position: Vector2 = _get_visual_base_position(player)
	_clear_breathing_tween(player, false)
	var start_position: Vector2 = player.position
	var target_position: Vector2 = _get_player_target_position(target_cell, _get_grid_layout())
	var midpoint_position: Vector2 = start_position.lerp(target_position, 0.5)
	var direction: Vector2i = target_cell - player_cell
	var lunge_scale: Vector2 = current_visual_scale
	var impact_scale: Vector2 = base_visual_scale

	if direction.x != 0:
		lunge_scale.x = current_visual_scale.x * PLAYER_MOVE_STRETCH_SCALE
		impact_scale.x = base_visual_scale.x * MINING_IMPACT_AXIS_SCALE
		impact_scale.y = base_visual_scale.y * MINING_IMPACT_PERPENDICULAR_SCALE
	else:
		lunge_scale.y = current_visual_scale.y * PLAYER_MOVE_STRETCH_SCALE
		impact_scale.y = base_visual_scale.y * MINING_IMPACT_AXIS_SCALE
		impact_scale.x = base_visual_scale.x * MINING_IMPACT_PERPENDICULAR_SCALE

	var lunge_duration: float = duration * MINING_LUNGE_RATIO
	var recover_duration: float = maxf(0.0, duration - lunge_duration)
	var move_tween: Tween = create_tween()
	active_move_tweens.append(move_tween)
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(player, "position", midpoint_position, lunge_duration)
	move_tween.tween_property(player, "position", start_position, recover_duration)

	var visual_tween: Tween = create_tween()
	active_move_tweens.append(visual_tween)
	visual_tween.set_trans(Tween.TRANS_QUAD)
	visual_tween.set_ease(Tween.EASE_OUT)
	visual_tween.tween_property(breathing_target, "scale", lunge_scale, lunge_duration)
	visual_tween.parallel().tween_property(breathing_target, "position", current_visual_position, lunge_duration)
	visual_tween.tween_callback(Callable(self, "_apply_mining_impact_pose").bind(breathing_target, impact_scale, base_visual_position))
	visual_tween.tween_property(breathing_target, "scale", base_visual_scale, recover_duration)
	visual_tween.parallel().tween_property(breathing_target, "position", base_visual_position, recover_duration)


func _apply_mining_impact_pose(breathing_target: Node2D, impact_scale: Vector2, base_visual_position: Vector2) -> void:
	if breathing_target == null or not is_instance_valid(breathing_target):
		return

	breathing_target.scale = impact_scale
	breathing_target.position = base_visual_position


func _animate_mined_rock(rock: Node2D, duration: float, delay: float = 0.0) -> void:
	if rock == null:
		return

	var available_duration: float = maxf(0.0, duration - delay)
	var shake_duration: float = minf(MINING_SHAKE_DURATION, available_duration)
	var shake_step_duration: float = shake_duration / float(MINING_SHAKE_STEPS)
	var fade_duration: float = maxf(0.0, available_duration - shake_duration)
	var origin: Vector2 = rock.position
	rock.modulate.a = 1.0
	pending_mined_rocks.append(rock)
	var tween: Tween = create_tween()
	active_move_tweens.append(tween)

	if delay > 0.0:
		tween.tween_interval(delay)

	for _shake_index in range(MINING_SHAKE_STEPS):
		var offset: Vector2 = Vector2(
			rng.randf_range(-MINING_SHAKE_DISTANCE, MINING_SHAKE_DISTANCE),
			rng.randf_range(-MINING_SHAKE_DISTANCE, MINING_SHAKE_DISTANCE)
		)

		if offset.length() > MINING_SHAKE_DISTANCE:
			offset = offset.normalized() * MINING_SHAKE_DISTANCE

		tween.tween_property(rock, "position", origin + offset, shake_step_duration)

	if shake_duration > 0.0:
		tween.tween_property(rock, "position", origin, 0.0)

	if fade_duration > 0.0:
		tween.tween_property(rock, "modulate:a", 0.0, fade_duration)


func _finalize_pending_mined_rocks() -> void:
	for rock in pending_mined_rocks:
		if rock != null and is_instance_valid(rock):
			rock.queue_free()

	pending_mined_rocks.clear()


func _run_turn(player_target_cell: Vector2i, player_moves: bool, player_action_duration: float = 0.0) -> void:
	var ghost_plans: Array = planned_red_ghost_turns

	if ghost_plans.is_empty():
		ghost_plans = _plan_red_ghost_turns()

	var first_step_targets: Dictionary = _get_ghost_step_targets(ghost_plans, 0)
	var did_trigger_mine: bool = await _run_turn_step(player_target_cell, player_moves, first_step_targets, player_action_duration)

	if is_game_over:
		return

	if did_trigger_mine:
		_reset_turn_bonus_counters()
		_refresh_enemy_turn_preview()
		return

	if player_moves and player_cell == exit_cell:
		_reset_turn_bonus_counters()
		_open_shop()
		return

	var second_step_targets: Dictionary = _get_ghost_step_targets(ghost_plans, 1)

	if second_step_targets.is_empty():
		_reset_turn_bonus_counters()
		_refresh_enemy_turn_preview()
		return

	did_trigger_mine = await _run_turn_step(player_cell, false, second_step_targets)

	if is_game_over:
		return

	if did_trigger_mine:
		_reset_turn_bonus_counters()
		_refresh_enemy_turn_preview()
		return

	_reset_turn_bonus_counters()
	_refresh_enemy_turn_preview()


func _run_turn_step(player_target_cell: Vector2i, player_moves: bool, ghost_targets: Dictionary, player_action_duration: float = 0.0) -> bool:
	var player_start_cell: Vector2i = player_cell
	var ghost_start_cells: Array[Vector2i] = red_ghost_cells.duplicate()
	var max_duration: float = player_action_duration
	var player_direction: Vector2i = player_target_cell - player_start_cell

	if player_moves and player_target_cell != player_start_cell:
		var player_target_position: Vector2 = _get_player_target_position(player_target_cell, _get_grid_layout())
		_create_move_tween(player, player_target_position, PLAYER_MOVE_DURATION, player_direction)
		max_duration = maxf(max_duration, PLAYER_MOVE_DURATION)

	for ghost_index in range(red_ghosts.size()):
		if not ghost_targets.has(ghost_index):
			continue

		var ghost_target_cell: Vector2i = ghost_targets[ghost_index]
		var ghost_start_cell: Vector2i = ghost_start_cells[ghost_index]

		if ghost_target_cell == ghost_start_cell:
			continue

		var ghost_target_position: Vector2 = _get_cell_center_position(ghost_target_cell, _get_grid_layout())
		var ghost_direction: Vector2i = ghost_target_cell - ghost_start_cell
		_create_move_tween(red_ghosts[ghost_index], ghost_target_position, ENEMY_MOVE_DURATION, ghost_direction)
		max_duration = maxf(max_duration, ENEMY_MOVE_DURATION)

	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout
		_clear_active_move_tweens()
		_finalize_pending_mined_rocks()
		_finalize_pending_removed_ghosts()
		_clear_shovel_fist_effects()

		if player_moves and player_target_cell != player_start_cell:
			_start_breathing(player)
		elif player_action_duration > 0.0:
			player.position = _get_player_target_position(player_cell, _get_grid_layout())
			_start_breathing(player)

		for ghost_index in ghost_targets.keys():
			if ghost_index >= 0 and ghost_index < red_ghosts.size():
				_start_breathing(red_ghosts[ghost_index])

	if player_moves:
		player_cell = player_target_cell
		player.position = _get_player_target_position(player_target_cell, _get_grid_layout())
		_collect_crystal_at_cell(player_cell)
		_trigger_exit_ping(true)

	for ghost_index in ghost_targets.keys():
		if ghost_index < 0 or ghost_index >= red_ghost_cells.size():
			continue

		red_ghost_cells[ghost_index] = ghost_targets[ghost_index]

	var exploded_ghost_indices: Array[int] = []
	var did_trigger_mine: bool = false

	var triggered_mine_cells: Array[Vector2i] = []

	for ghost_cell in red_ghost_cells:
		if _has_any_mine_at_cell(ghost_cell) and not triggered_mine_cells.has(ghost_cell):
			triggered_mine_cells.append(ghost_cell)

	for detonated_mine_cell in triggered_mine_cells:
		exploded_ghost_indices.append_array(_trigger_mine_explosion(detonated_mine_cell, PLAYER_MOVE_DURATION))
		did_trigger_mine = true

		if _does_mine_explosion_hit_player(detonated_mine_cell) and not _try_ignore_mine_damage():
			await _trigger_game_over()
			return did_trigger_mine

	var colliding_ghost_indices: Array[int] = _get_player_collision_indices(player_start_cell, player_target_cell, player_moves, ghost_start_cells, ghost_targets, exploded_ghost_indices)

	if not colliding_ghost_indices.is_empty() and not _resolve_spiked_armor_collisions(colliding_ghost_indices):
		await _trigger_game_over()
		return did_trigger_mine

	_remove_red_ghosts_by_indices(exploded_ghost_indices)

	_update_movement_buttons()
	return did_trigger_mine


func _create_move_tween(node: Node2D, target_position: Vector2, duration: float, direction: Vector2i = Vector2i.ZERO) -> Tween:
	var tween: Tween = create_tween()
	active_move_tweens.append(tween)
	tween.tween_property(node, "position", target_position, duration)

	if node == player and direction != Vector2i.ZERO:
		_create_player_move_visual_tween(direction, duration)
	elif direction != Vector2i.ZERO:
		_create_move_visual_tween(node, direction, duration, GHOST_MOVE_STRETCH_SCALE)

	return tween


func _clear_active_move_tweens() -> void:
	for tween in active_move_tweens:
		if tween != null and is_instance_valid(tween):
			tween.kill()

	active_move_tweens.clear()


func _step_has_player_collision(player_start_cell: Vector2i, player_target_cell: Vector2i, player_moves: bool, ghost_start_cells: Array[Vector2i], ghost_targets: Dictionary, ignored_ghost_indices: Array[int] = []) -> bool:
	return RED_GHOST_SYSTEM.step_has_player_collision(self, player_start_cell, player_target_cell, player_moves, ghost_start_cells, ghost_targets, ignored_ghost_indices)


func _get_player_collision_indices(player_start_cell: Vector2i, player_target_cell: Vector2i, player_moves: bool, ghost_start_cells: Array[Vector2i], ghost_targets: Dictionary, ignored_ghost_indices: Array[int] = []) -> Array[int]:
	return RED_GHOST_SYSTEM.get_player_collision_indices(self, player_start_cell, player_target_cell, player_moves, ghost_start_cells, ghost_targets, ignored_ghost_indices)


func _get_ghost_step_targets(ghost_plans: Array, step_index: int) -> Dictionary:
	return RED_GHOST_SYSTEM.get_ghost_step_targets(self, ghost_plans, step_index)


func _run_enemy_turns() -> void:
	if red_ghosts.is_empty():
		planned_red_ghost_turns.clear()
		return

	await _run_turn(player_cell, false)


func _plan_red_ghost_turns() -> Array:
	return RED_GHOST_SYSTEM.plan_red_ghost_turns(self)


func _refresh_enemy_turn_preview() -> void:
	RED_GHOST_SYSTEM.refresh_enemy_turn_preview(self)


func _show_existing_enemy_turn_preview() -> void:
	_clear_enemy_highlights()

	if planned_red_ghost_turns.is_empty():
		return

	var highlight_cells: Array[Vector2i] = []

	for ghost_plan in planned_red_ghost_turns:
		var path: Array[Vector2i] = ghost_plan["path"]

		for cell in path:
			highlight_cells.append(cell)

	_show_enemy_highlights(highlight_cells)


func _get_random_red_ghost_step(current_cell: Vector2i, occupied_cells: Array[Vector2i], ghost_index: int) -> Vector2i:
	return RED_GHOST_SYSTEM.get_random_red_ghost_step(self, current_cell, occupied_cells, ghost_index)


func _regenerate_level(advance_level: bool) -> void:
	if advance_level:
		current_level += 1

	_stop_exit_ping()
	_clear_active_move_tweens()
	_finalize_pending_mined_rocks()
	_finalize_pending_removed_ghosts()
	_clear_collectible_mines()
	_clear_explosion_effects()
	_clear_shovel_fist_effects()
	_clear_active_mine(advance_level)
	_close_shop()
	_reset_floor_upgrade_state()
	is_press_active = false
	pressed_cell = INVALID_CELL
	is_game_over = false
	is_turn_resolving = false
	position = Vector2.ZERO
	_clear_player_move_highlights()
	_clear_crystals()

	_initialize_map_state()
	_spawn_rocks()
	_place_exit()
	_place_player()
	_spawn_red_ghosts()
	_spawn_map_crystals()
	_spawn_collectible_mines()
	_refresh_enemy_turn_preview()
	_update_resource_labels()
	_update_movement_buttons()
	_start_exit_ping()

	if game_over_root != null:
		game_over_root.visible = false


func _has_red_ghost_at_cell(cell: Vector2i) -> bool:
	return RED_GHOST_SYSTEM.has_red_ghost_at_cell(self, cell)


func _trigger_game_over() -> void:
	if is_game_over:
		return

	_stop_exit_ping()
	_clear_active_move_tweens()
	_finalize_pending_mined_rocks()
	_finalize_pending_removed_ghosts()
	_clear_collectible_mines()
	_clear_explosion_effects()
	_clear_shovel_fist_effects()
	is_press_active = false
	pressed_cell = INVALID_CELL
	is_game_over = true
	is_turn_resolving = true
	planned_red_ghost_turns.clear()
	_clear_player_move_highlights()
	_clear_enemy_highlights()
	_update_movement_buttons()
	await _shake_screen()

	if game_over_root != null:
		game_over_root.visible = true


func _shake_screen() -> void:
	var shake_offsets: Array[Vector2] = [
		Vector2(-SCREEN_SHAKE_OFFSET, 0.0),
		Vector2(SCREEN_SHAKE_OFFSET, 0.0),
		Vector2(0.0, -SCREEN_SHAKE_OFFSET * 0.6),
		Vector2(0.0, SCREEN_SHAKE_OFFSET * 0.6),
		Vector2(-SCREEN_SHAKE_OFFSET * 0.5, SCREEN_SHAKE_OFFSET * 0.35),
		Vector2(SCREEN_SHAKE_OFFSET * 0.5, -SCREEN_SHAKE_OFFSET * 0.35),
		Vector2.ZERO,
	]

	for offset in shake_offsets:
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", offset, SCREEN_SHAKE_STEP_DURATION)
		await tween.finished

	position = Vector2.ZERO


func _on_retry_pressed() -> void:
	current_level = 1
	available_mines = 0
	max_shovel_fists = DEFAULT_SHOVEL_FIST_CHARGES
	available_shovel_fists = max_shovel_fists
	crystal_total = 0
	_update_resource_labels()
	_clear_collectible_mines()
	_clear_active_mine(false)
	_clear_explosion_effects()
	_clear_shovel_fist_effects()
	_clear_crystals()
	_regenerate_level(false)


func _get_grid_layout() -> Dictionary:
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var rock_bounds: Rect2 = _get_rock_bounds()
	var base_rock_size: Vector2 = rock_bounds.size
	var rock_scale_factor: float = _get_rock_scale_factor(visible_rect.size, base_rock_size)
	var scaled_rock_size: Vector2 = base_rock_size * rock_scale_factor
	var horizontal_gap: float = scaled_rock_size.x * ROCK_GAP_RATIO
	var vertical_gap: float = scaled_rock_size.y * ROCK_GAP_RATIO
	var horizontal_step: float = scaled_rock_size.x + horizontal_gap
	var vertical_step: float = scaled_rock_size.y + vertical_gap
	var total_width: float = scaled_rock_size.x * MAP_WIDTH + horizontal_gap * float(MAP_WIDTH - 1)
	var total_height: float = scaled_rock_size.y * MAP_HEIGHT + vertical_gap * float(MAP_HEIGHT - 1)

	return {
		"rock_scale_factor": rock_scale_factor,
		"scaled_rock_size": scaled_rock_size,
		"scaled_left_extent": rock_bounds.position.x * rock_scale_factor,
		"scaled_bottom_extent": (rock_bounds.position.y + rock_bounds.size.y) * rock_scale_factor,
		"horizontal_step": horizontal_step,
		"vertical_step": vertical_step,
		"grid_left": visible_rect.position.x + (visible_rect.size.x - total_width) / 2.0,
		"grid_bottom": visible_rect.position.y + visible_rect.size.y - (visible_rect.size.y - total_height) / 2.0,
	}


func _get_rock_bounds() -> Rect2:
	var rock: Node2D = ROCK_SCENE.instantiate() as Node2D
	var sprite: Sprite2D = rock.get_node("Rock") as Sprite2D

	if sprite == null or sprite.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ONE)

	var sprite_size: Vector2 = sprite.texture.get_size() * sprite.scale
	var top_left: Vector2 = sprite.position - sprite_size / 2.0

	return Rect2(top_left, sprite_size)


func _get_rock_scale_factor(viewport_size: Vector2, base_rock_size: Vector2) -> float:
	if base_rock_size.x <= 0.0 or base_rock_size.y <= 0.0:
		return 1.0

	var max_rock_width: float = viewport_size.x / (float(MAP_WIDTH) + float(MAP_WIDTH - 1) * ROCK_GAP_RATIO)
	var max_rock_height: float = viewport_size.y / (float(MAP_HEIGHT) + float(MAP_HEIGHT - 1) * ROCK_GAP_RATIO)
	var width_scale: float = max_rock_width / base_rock_size.x
	var height_scale: float = max_rock_height / base_rock_size.y

	return min(width_scale, height_scale)
