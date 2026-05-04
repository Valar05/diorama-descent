extends RefCounted


static func has_shovel_fist_charge(world) -> bool:
	return world.available_shovel_fists > 0


static func get_shovel_fist_target_index(world, cell: Vector2i) -> int:
	if not has_shovel_fist_charge(world):
		return -1

	for ghost_index in range(world.red_ghost_cells.size()):
		if world.red_ghost_cells[ghost_index] != cell:
			continue

		if is_ghost_eligible_for_shovel_fist(world, ghost_index):
			return ghost_index

	return -1


static func is_ghost_eligible_for_shovel_fist(world, ghost_index: int) -> bool:
	if ghost_index < 0 or ghost_index >= world.red_ghost_cells.size():
		return false

	var target_cell: Vector2i = world.red_ghost_cells[ghost_index]

	if not world._is_cell_in_influence_reach(target_cell):
		return false

	return has_clear_line_of_effect(world, world.player_cell, target_cell)


static func is_enemy_cell_eligible_for_shovel_fist(world, cell: Vector2i) -> bool:
	var ghost_index: int = get_shovel_fist_target_index(world, cell)
	return ghost_index != -1


static func has_clear_line_of_effect(world, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var line_cells: Array[Vector2i] = get_line_cells(world, from_cell, to_cell)

	if line_cells.size() <= 2:
		return true

	for cell_index in range(1, line_cells.size() - 1):
		if world._is_cell_occupied(line_cells[cell_index]):
			return false

	return true


static func get_line_cells(_world, from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var delta_x: int = absi(x1 - x0)
	var step_x: int = 1 if x0 < x1 else -1
	var delta_y: int = -absi(y1 - y0)
	var step_y: int = 1 if y0 < y1 else -1
	var error: int = delta_x + delta_y

	while true:
		cells.append(Vector2i(x0, y0))

		if x0 == x1 and y0 == y1:
			break

		var double_error: int = error * 2

		if double_error >= delta_y:
			error += delta_y
			x0 += step_x

		if double_error <= delta_x:
			error += delta_x
			y0 += step_y

	return cells


static func use_shovel_fist_on_ghost(world, ghost_index: int) -> void:
	if world.is_turn_resolving or not is_ghost_eligible_for_shovel_fist(world, ghost_index):
		return

	world.is_turn_resolving = true
	world._clear_player_move_highlights()
	world._clear_enemy_highlights()
	world._update_movement_buttons()
	world.available_shovel_fists -= 1
	world._update_resource_labels()
	var action_duration: float = animate_shovel_fist_attack(world, ghost_index, world.PLAYER_MOVE_DURATION)
	world.planned_red_ghost_turns.clear()
	await world._run_turn_step(world.player_cell, false, {}, action_duration)
	if world.is_game_over:
		return
	world._reset_turn_bonus_counters()
	world._refresh_enemy_turn_preview()
	world.is_turn_resolving = false
	world._update_movement_buttons()


static func animate_shovel_fist_attack(world, ghost_index: int, duration: float) -> float:
	if ghost_index < 0 or ghost_index >= world.red_ghosts.size() or world.player == null:
		return 0.0

	world.planned_red_ghost_turns.clear()

	var ghost: Node2D = world.red_ghosts[ghost_index]

	if ghost == null:
		return 0.0

	var projectile: Node2D = world.SHOVEL_FIST_SCENE.instantiate() as Node2D

	if projectile == null:
		return 0.0

	var start_position: Vector2 = world._get_cell_center_position(world.player_cell, world._get_grid_layout())
	var impact_position: Vector2 = world._get_cell_center_position(world.red_ghost_cells[ghost_index], world._get_grid_layout())
	projectile.name = "ShovelFist"
	projectile.z_index = 6
	projectile.position = start_position
	projectile.rotation = (impact_position - start_position).angle()
	world.add_child(projectile)
	world.active_shovel_fist_effects.append(projectile)

	var travel_duration: float = duration * world.SHOVEL_FIST_PROJECTILE_RATIO
	var push_duration: float = duration * world.SHOVEL_FIST_PUSH_RATIO
	var projectile_tween: Tween = world.create_tween()
	world.active_move_tweens.append(projectile_tween)
	projectile_tween.tween_property(projectile, "position", impact_position, travel_duration)
	projectile_tween.tween_callback(Callable(projectile, "queue_free"))
	var push_direction: Vector2i = get_shovel_fist_push_direction(world, world.red_ghost_cells[ghost_index])
	var chain_depth: int = estimate_shovel_chain_depth(world, ghost_index, push_direction, {})
	schedule_shovel_chain(world, ghost, push_direction, travel_duration, push_duration)
	return travel_duration + push_duration * float(maxi(1, chain_depth))


static func schedule_shovel_chain(world, ghost: Node2D, push_direction: Vector2i, start_delay: float, push_duration: float) -> void:
	var ghost_index: int = world.red_ghosts.find(ghost)

	if ghost_index == -1:
		return

	var start_cell: Vector2i = world.red_ghost_cells[ghost_index]
	var push_path: Array[Vector2i] = get_shovel_fist_push_path_in_direction(world, start_cell, push_direction)
	var collision_ghost_index: int = get_shovel_fist_collision_ghost_index_in_direction(world, ghost_index, push_direction, push_path)
	var did_die: bool = shovel_fist_hits_wall_or_edge_in_direction(world, start_cell, push_direction, push_path)
	var final_cell: Vector2i = start_cell

	if not push_path.is_empty():
		final_cell = push_path[push_path.size() - 1]

	var impact_duration: float = push_duration * 0.24 if did_die or collision_ghost_index != -1 else 0.0
	var path_duration: float = maxf(0.0, push_duration - impact_duration)

	if not push_path.is_empty():
		var push_tween: Tween = world.create_tween()
		world.active_move_tweens.append(push_tween)
		push_tween.tween_interval(start_delay)
		var step_duration: float = path_duration / float(push_path.size()) if path_duration > 0.0 else 0.0

		for cell in push_path:
			push_tween.tween_property(ghost, "position", world._get_cell_center_position(cell, world._get_grid_layout()), step_duration)

		world.red_ghost_cells[ghost_index] = final_cell

	if collision_ghost_index != -1:
		var blocker_ghost: Node2D = world.red_ghosts[collision_ghost_index]
		var collision_tween: Tween = world.create_tween()
		world.active_move_tweens.append(collision_tween)
		collision_tween.tween_interval(start_delay + path_duration)
		var collision_cell: Vector2i = world.red_ghost_cells[collision_ghost_index]
		var impact_position_target: Vector2 = get_shovel_fist_block_impact_position(world, collision_cell, push_direction)
		collision_tween.tween_property(ghost, "position", impact_position_target, impact_duration)
		collision_tween.tween_callback(Callable(world, "_on_shovel_collision_impact").bind(ghost, blocker_ghost, push_direction, push_duration))
		return

	if did_die:
		var detached_ghost: Node2D = ghost
		var detached_ghost_index: int = world.red_ghosts.find(ghost)

		if detached_ghost_index != -1:
			detached_ghost = world._detach_red_ghost_at_index(detached_ghost_index)

		var death_tween: Tween = world.create_tween()
		death_tween.tween_interval(start_delay + path_duration)
		var impact_position_target: Vector2 = get_shovel_fist_block_impact_position(world, final_cell, push_direction)
		death_tween.tween_property(detached_ghost, "position", impact_position_target, impact_duration)
		death_tween.tween_callback(Callable(world, "_animate_removed_ghost").bind(detached_ghost))
		return

	if world._has_any_mine_at_cell(final_cell):
		var detonated_mine_cell: Vector2i = final_cell
		var mine_tween: Tween = world.create_tween()
		mine_tween.tween_interval(start_delay + path_duration)
		mine_tween.tween_callback(Callable(world, "_on_shovel_mine_collision").bind(ghost, detonated_mine_cell))


static func handle_shovel_wall_impact(world, ghost: Node2D) -> void:
	var ghost_index: int = world.red_ghosts.find(ghost)
	var detached_ghost: Node2D = ghost

	if ghost_index != -1:
		detached_ghost = world._detach_red_ghost_at_index(ghost_index)

	if detached_ghost != null:
		world._animate_removed_ghost(detached_ghost)


static func handle_shovel_collision_impact(world, incoming_ghost: Node2D, blocker_ghost: Node2D, push_direction: Vector2i, push_duration: float) -> void:
	handle_shovel_wall_impact(world, incoming_ghost)
	schedule_shovel_chain(world, blocker_ghost, push_direction, 0.0, push_duration)


static func estimate_shovel_chain_depth(world, ghost_index: int, push_direction: Vector2i, visited: Dictionary) -> int:
	if visited.has(ghost_index):
		return 1

	visited[ghost_index] = true
	var start_cell: Vector2i = world.red_ghost_cells[ghost_index]
	var push_path: Array[Vector2i] = get_shovel_fist_push_path_in_direction(world, start_cell, push_direction)
	var collision_ghost_index: int = get_shovel_fist_collision_ghost_index_in_direction(world, ghost_index, push_direction, push_path)

	if collision_ghost_index != -1:
		return 1 + estimate_shovel_chain_depth(world, collision_ghost_index, push_direction, visited)

	return 1


static func handle_shovel_mine_collision(world, ghost: Node2D, detonated_mine_cell: Vector2i) -> void:
	if ghost == null or not is_instance_valid(ghost):
		return

	var ghost_index: int = world.red_ghosts.find(ghost)

	if ghost_index == -1:
		return

	var destroyed_ghost_indices: Array[int] = world._trigger_mine_explosion(detonated_mine_cell, world.PLAYER_MOVE_DURATION)
	world._remove_red_ghosts_by_indices(destroyed_ghost_indices)

	if world._does_mine_explosion_hit_player(detonated_mine_cell) and not world._try_ignore_mine_damage():
		world._trigger_game_over()

static func get_shovel_fist_block_impact_position(world, final_cell: Vector2i, push_direction: Vector2i) -> Vector2:
	var grid_layout: Dictionary = world._get_grid_layout()
	var final_position: Vector2 = world._get_cell_center_position(final_cell, grid_layout)
	var overshoot_offset: Vector2 = Vector2(
		float(push_direction.x) * grid_layout["horizontal_step"] * 0.28,
		float(-push_direction.y) * grid_layout["vertical_step"] * 0.28
	)
	return final_position + overshoot_offset


static func get_shovel_fist_push_path_in_direction(world, start_cell: Vector2i, push_direction: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	if push_direction == Vector2i.ZERO:
		return path

	var current_cell: Vector2i = start_cell
	var step_count: int = 0
	var max_push_tiles: int = world._get_shovel_push_distance()

	while true:
		if step_count >= max_push_tiles:
			break

		var next_cell: Vector2i = current_cell + push_direction

		if not world._is_in_bounds(next_cell):
			break

		if world._is_cell_occupied(next_cell):
			break

		if world.red_ghost_cells.has(next_cell):
			break

		path.append(next_cell)
		current_cell = next_cell
		step_count += 1

	return path


static func get_shovel_fist_collision_ghost_index(world, pushed_ghost_index: int, push_path: Array[Vector2i]) -> int:
	var push_direction: Vector2i = get_shovel_fist_push_direction(world, world.red_ghost_cells[pushed_ghost_index])
	return get_shovel_fist_collision_ghost_index_in_direction(world, pushed_ghost_index, push_direction, push_path)


static func get_shovel_fist_collision_ghost_index_in_direction(world, pushed_ghost_index: int, push_direction: Vector2i, push_path: Array[Vector2i]) -> int:

	if push_direction == Vector2i.ZERO:
		return -1

	var final_cell: Vector2i = world.red_ghost_cells[pushed_ghost_index]

	if not push_path.is_empty():
		final_cell = push_path[push_path.size() - 1]

	var collision_cell: Vector2i = final_cell + push_direction

	if not world._is_in_bounds(collision_cell):
		return -1

	for other_ghost_index in range(world.red_ghost_cells.size()):
		if other_ghost_index == pushed_ghost_index:
			continue

		if world.red_ghost_cells[other_ghost_index] == collision_cell:
			return other_ghost_index

	return -1


static func get_shovel_fist_push_direction(world, target_cell: Vector2i) -> Vector2i:
	var offset: Vector2i = target_cell - world.player_cell
	var x_direction: int = 0
	var y_direction: int = 0

	if offset.x < 0:
		x_direction = -1
	elif offset.x > 0:
		x_direction = 1

	if offset.y < 0:
		y_direction = -1
	elif offset.y > 0:
		y_direction = 1

	return Vector2i(x_direction, y_direction)


static func get_shovel_fist_push_path(world, start_cell: Vector2i) -> Array[Vector2i]:
	var push_direction: Vector2i = get_shovel_fist_push_direction(world, start_cell)
	return get_shovel_fist_push_path_in_direction(world, start_cell, push_direction)


static func shovel_fist_hits_wall_or_edge(world, start_cell: Vector2i) -> bool:
	var push_direction: Vector2i = get_shovel_fist_push_direction(world, start_cell)
	var path: Array[Vector2i] = get_shovel_fist_push_path_in_direction(world, start_cell, push_direction)
	return shovel_fist_hits_wall_or_edge_in_direction(world, start_cell, push_direction, path)


static func shovel_fist_hits_wall_or_edge_in_direction(world, start_cell: Vector2i, push_direction: Vector2i, path: Array[Vector2i]) -> bool:

	if push_direction == Vector2i.ZERO:
		return false

	var end_cell: Vector2i = start_cell

	if not path.is_empty():
		end_cell = path[path.size() - 1]

	if path.size() < world.SHOVEL_FIST_MAX_PUSH_TILES:
		var collision_cell: Vector2i = end_cell + push_direction

		if not world._is_in_bounds(collision_cell):
			return true

		return world._is_cell_occupied(collision_cell)

	return false


static func clear_shovel_fist_effects(world) -> void:
	for effect in world.active_shovel_fist_effects:
		if effect != null and is_instance_valid(effect):
			effect.queue_free()

	world.active_shovel_fist_effects.clear()