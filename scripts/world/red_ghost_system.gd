extends RefCounted


static func spawn_red_ghosts(world) -> void:
	clear_red_ghosts(world)
	world.red_ghost_cells.clear()

	var spawn_cells: Array[Vector2i] = get_red_ghost_spawn_cells(world, world.current_level)

	for index in range(spawn_cells.size()):
		var ghost: Node2D = world.RED_GHOST_SCENE.instantiate() as Node2D

		if ghost == null:
			continue

		ghost.name = "RedGhost%d" % (index + 1)
		ghost.z_index = 4
		world.add_child(ghost)
		world._start_breathing(ghost)
		world.red_ghosts.append(ghost)
		world.red_ghost_cells.append(spawn_cells[index])
		ghost.position = world._get_cell_center_position(spawn_cells[index], world._get_grid_layout())


static func clear_red_ghosts(world) -> void:
	for ghost in world.red_ghosts:
		if ghost != null:
			world._clear_breathing_tween(ghost)
			ghost.queue_free()

	world._finalize_pending_removed_ghosts()
	world.red_ghosts.clear()
	world.red_ghost_cells.clear()


static func detach_red_ghost_at_index(world, ghost_index: int) -> Node2D:
	if ghost_index < 0 or ghost_index >= world.red_ghosts.size():
		return null

	var ghost: Node2D = world.red_ghosts[ghost_index]
	world.red_ghosts.remove_at(ghost_index)
	world.red_ghost_cells.remove_at(ghost_index)
	return ghost


static func has_red_ghost_at_cell(world, cell: Vector2i) -> bool:
	return world.red_ghost_cells.has(cell)


static func get_red_ghost_indices_in_cells(world, cells: Array[Vector2i]) -> Array[int]:
	var destroyed_indices: Array[int] = []

	for ghost_index in range(world.red_ghost_cells.size()):
		if cells.has(world.red_ghost_cells[ghost_index]):
			destroyed_indices.append(ghost_index)

	return destroyed_indices


static func remove_red_ghosts_by_indices(world, indices: Array[int]) -> void:
	var unique_indices: Dictionary = {}

	for ghost_index in indices:
		unique_indices[ghost_index] = true

	var sorted_indices: Array[int] = []

	for ghost_index in unique_indices.keys():
		sorted_indices.append(ghost_index as int)

	sorted_indices.sort()
	sorted_indices.reverse()

	for ghost_index in sorted_indices:
		if ghost_index < 0 or ghost_index >= world.red_ghosts.size():
			continue

		var ghost: Node2D = detach_red_ghost_at_index(world, ghost_index)
		if ghost != null:
			world._animate_removed_ghost(ghost)


static func get_red_ghost_spawn_cells(world, ghost_count: int) -> Array[Vector2i]:
	var spawn_cells: Array[Vector2i] = []
	var map_center: Vector2 = Vector2((world.MAP_WIDTH - 1) / 2.0, (world.MAP_HEIGHT - 1) / 2.0)

	for _ghost_index in range(ghost_count):
		var candidate_cells: Array[Vector2i] = []
		var best_distance: float = INF

		for row_index in range(world.MAP_HEIGHT):
			for column_index in range(world.MAP_WIDTH):
				var cell: Vector2i = Vector2i(column_index, row_index)

				if world._is_cell_occupied(cell):
					continue

				if cell == world.player_cell or cell == world.exit_cell:
					continue

				if spawn_cells.has(cell):
					continue

				var distance_to_center: float = Vector2(float(cell.x), float(cell.y)).distance_squared_to(map_center)

				if distance_to_center < best_distance:
					best_distance = distance_to_center
					candidate_cells = [cell]
				elif is_equal_approx(distance_to_center, best_distance):
					candidate_cells.append(cell)

		if candidate_cells.is_empty():
			break

		spawn_cells.append(candidate_cells[world.rng.randi_range(0, candidate_cells.size() - 1)])

	return spawn_cells


static func show_enemy_highlights(world, cells: Array[Vector2i]) -> void:
	clear_enemy_highlights(world)

	if world.enemy_highlight_root == null:
		return

	var unique_cells: Dictionary = {}
	var grid_layout: Dictionary = world._get_grid_layout()

	for cell in cells:
		unique_cells[cell] = true

	for cell in unique_cells.keys():
		var rect: Rect2 = world._get_cell_highlight_rect(cell, grid_layout)
		var panel: Panel = Panel.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = world.ENEMY_HIGHLIGHT_FILL
		style.border_color = world.ENEMY_HIGHLIGHT_BORDER
		style.set_border_width_all(3)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		panel.position = rect.position
		panel.size = rect.size
		world.enemy_highlight_root.add_child(panel)
		world.enemy_highlights.append(panel)


static func clear_enemy_highlights(world) -> void:
	for highlight in world.enemy_highlights:
		if highlight != null:
			highlight.queue_free()

	world.enemy_highlights.clear()


static func step_has_player_collision(_world, player_start_cell: Vector2i, player_target_cell: Vector2i, player_moves: bool, ghost_start_cells: Array[Vector2i], ghost_targets: Dictionary, ignored_ghost_indices: Array[int] = []) -> bool:
	return not get_player_collision_indices(_world, player_start_cell, player_target_cell, player_moves, ghost_start_cells, ghost_targets, ignored_ghost_indices).is_empty()


static func get_player_collision_indices(_world, player_start_cell: Vector2i, player_target_cell: Vector2i, player_moves: bool, ghost_start_cells: Array[Vector2i], ghost_targets: Dictionary, ignored_ghost_indices: Array[int] = []) -> Array[int]:
	var colliding_indices: Array[int] = []

	for ghost_index in ghost_targets.keys():
		if ignored_ghost_indices.has(ghost_index):
			continue

		if ghost_index < 0 or ghost_index >= ghost_start_cells.size():
			continue

		var ghost_start_cell: Vector2i = ghost_start_cells[ghost_index]
		var ghost_target_cell: Vector2i = ghost_targets[ghost_index]

		if ghost_target_cell == player_target_cell:
			colliding_indices.append(ghost_index)
			continue

		if player_moves and ghost_start_cell == player_target_cell and ghost_target_cell == player_start_cell:
			colliding_indices.append(ghost_index)

	return colliding_indices


static func get_ghost_step_targets(_world, ghost_plans: Array, step_index: int) -> Dictionary:
	var targets: Dictionary = {}

	for ghost_plan in ghost_plans:
		var ghost_index: int = ghost_plan["ghost_index"]
		var path: Array[Vector2i] = ghost_plan["path"]

		if step_index >= path.size():
			continue

		targets[ghost_index] = path[step_index]

	return targets


static func plan_red_ghost_turns(world) -> Array:
	var plans: Array = []
	var simulated_positions: Array[Vector2i] = world.red_ghost_cells.duplicate()

	for ghost_index in range(world.red_ghosts.size()):
		var path: Array[Vector2i] = []
		var current_cell: Vector2i = simulated_positions[ghost_index]

		for _step in range(2):
			var next_cell: Vector2i = get_random_red_ghost_step(world, current_cell, simulated_positions, ghost_index)

			if next_cell == current_cell:
				continue

			path.append(next_cell)
			simulated_positions[ghost_index] = next_cell
			current_cell = next_cell

		plans.append({"ghost_index": ghost_index, "path": path})

	return plans


static func refresh_enemy_turn_preview(world) -> void:
	world.planned_red_ghost_turns.clear()
	clear_enemy_highlights(world)

	if world.red_ghosts.is_empty():
		return

	world.planned_red_ghost_turns = plan_red_ghost_turns(world)
	var highlight_cells: Array[Vector2i] = []

	for ghost_plan in world.planned_red_ghost_turns:
		var path: Array[Vector2i] = ghost_plan["path"]

		for cell in path:
			highlight_cells.append(cell)

	show_enemy_highlights(world, highlight_cells)


static func get_random_red_ghost_step(world, current_cell: Vector2i, occupied_cells: Array[Vector2i], ghost_index: int) -> Vector2i:
	var candidate_cells: Array[Vector2i] = []

	for direction in world._get_cardinal_directions():
		var next_cell: Vector2i = current_cell + direction

		if not world._is_in_bounds(next_cell):
			continue

		if world._is_cell_occupied(next_cell):
			continue

		if occupied_cells.has(next_cell) and occupied_cells.find(next_cell) != ghost_index:
			continue

		candidate_cells.append(next_cell)

	if candidate_cells.is_empty():
		return current_cell

	return candidate_cells[world.rng.randi_range(0, candidate_cells.size() - 1)]