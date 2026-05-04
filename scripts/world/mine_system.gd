extends RefCounted


static func can_place_mine_at_cell(world, cell: Vector2i) -> bool:
	if world.available_mines <= 0:
		return false

	if world.active_mine != null:
		return false

	if not world._is_in_bounds(cell):
		return false

	if not is_cell_in_influence_reach(world, cell):
		return false

	if world._is_cell_occupied(cell):
		return false

	if cell == world.player_cell or cell == world.exit_cell:
		return false

	if world._has_red_ghost_at_cell(cell):
		return false

	if world._has_crystal_at_cell(cell):
		return false

	if has_collectible_mine_at_cell(world, cell):
		return false

	return true


static func has_influence_action_available(world) -> bool:
	return world.available_mines > 0 or world.available_shovel_fists > 0


static func is_cell_in_influence_reach(world, cell: Vector2i) -> bool:
	if cell == world.player_cell:
		return false

	var offset: Vector2i = cell - world.player_cell
	return offset.length_squared() <= world.influence_reach * world.influence_reach


static func is_influence_dirt_cell(world, cell: Vector2i) -> bool:
	if not world._is_in_bounds(cell):
		return false

	if not is_cell_in_influence_reach(world, cell):
		return false

	if world._is_cell_occupied(cell):
		return false

	if cell == world.exit_cell:
		return false

	if world._has_red_ghost_at_cell(cell):
		return false

	if has_mine_at_cell(world, cell):
		return false

	return true


static func has_mine_at_cell(world, cell: Vector2i) -> bool:
	return world.active_mine != null and world.active_mine_cell == cell


static func has_armed_mine_at_cell(world, cell: Vector2i) -> bool:
	return world.active_mine != null and world.active_mine_cell == cell


static func has_collectible_mine_at_cell(world, cell: Vector2i) -> bool:
	return world.collectible_mines.has(cell)


static func has_any_mine_at_cell(world, cell: Vector2i) -> bool:
	return has_armed_mine_at_cell(world, cell) or has_collectible_mine_at_cell(world, cell)


static func place_active_mine(world, cell: Vector2i) -> void:
	if world.is_turn_resolving or not can_place_mine_at_cell(world, cell):
		return

	world.is_turn_resolving = true
	world._clear_player_move_highlights()
	world._clear_enemy_highlights()
	world._update_movement_buttons()
	spawn_active_mine(world, cell)
	world.available_mines = 0
	world._update_resource_labels()
	await world._run_turn(world.player_cell, false, world.PLAYER_MOVE_DURATION)
	if world.is_game_over:
		return
	world.is_turn_resolving = false
	world._update_movement_buttons()


static func take_back_active_mine(world) -> void:
	if world.is_turn_resolving or world.active_mine == null:
		return

	world.is_turn_resolving = true
	world._clear_player_move_highlights()
	world._clear_enemy_highlights()
	world._update_movement_buttons()
	clear_active_mine(world, true)
	await world._run_turn(world.player_cell, false, world.PLAYER_MOVE_DURATION)
	if world.is_game_over:
		return
	world.is_turn_resolving = false
	world._update_movement_buttons()


static func take_back_mine_at_cell(world, cell: Vector2i) -> void:
	if world.is_turn_resolving or not is_cell_in_influence_reach(world, cell):
		return

	if has_armed_mine_at_cell(world, cell):
		await take_back_active_mine(world)
		return

	if not has_collectible_mine_at_cell(world, cell):
		return

	world.is_turn_resolving = true
	world._clear_player_move_highlights()
	world._clear_enemy_highlights()
	world._update_movement_buttons()
	pick_up_collectible_mine(world, cell)
	await world._run_turn(world.player_cell, false, world.PLAYER_MOVE_DURATION)
	if world.is_game_over:
		return
	world.is_turn_resolving = false
	world._update_movement_buttons()


static func spawn_active_mine(world, cell: Vector2i) -> void:
	world.active_mine = world.MINE_SCENE.instantiate() as Node2D

	if world.active_mine == null:
		return

	world.active_mine.name = "Mine"
	world.active_mine.z_index = 3
	world.active_mine.position = world._get_cell_center_position(cell, world._get_grid_layout())
	world.active_mine_cell = cell
	world.add_child(world.active_mine)


static func clear_active_mine(world, refund: bool) -> void:
	if refund and world.active_mine_cell != world.INVALID_CELL:
		world.available_mines += 1

	if world.active_mine != null:
		world.active_mine.queue_free()

	world.active_mine = null
	world.active_mine_cell = world.INVALID_CELL
	world._update_resource_labels()


static func clear_collectible_mines(world) -> void:
	for mine in world.collectible_mines.values():
		var mine_node: Node2D = mine as Node2D

		if mine_node != null and is_instance_valid(mine_node):
			mine_node.queue_free()

	world.collectible_mines.clear()


static func spawn_collectible_mines(world) -> void:
	clear_collectible_mines(world)
	var mine_count: int = world.rng.randi_range(world.MIN_MAP_MINES, world.MAX_MAP_MINES)
	var candidate_cells: Array[Vector2i] = []

	for row_index in range(world.MAP_HEIGHT):
		for column_index in range(world.MAP_WIDTH):
			var cell: Vector2i = Vector2i(column_index, row_index)

			if cell == world.player_cell or cell == world.exit_cell:
				continue

			if world._has_red_ghost_at_cell(cell):
				continue

			if world._has_crystal_at_cell(cell):
				continue

			candidate_cells.append(cell)

	world._shuffle_cells(candidate_cells)

	for index in range(mini(mine_count, candidate_cells.size())):
		var cell: Vector2i = candidate_cells[index]
		place_collectible_mine(world, cell)


static func place_collectible_mine(world, cell: Vector2i) -> void:
	if has_collectible_mine_at_cell(world, cell):
		return

	if world._is_cell_occupied(cell):
		world._set_cell_occupied(cell, false)

		if world.rock_nodes.has(cell):
			var rock: Node2D = world.rock_nodes[cell] as Node2D
			world.rock_nodes.erase(cell)

			if rock != null:
				rock.queue_free()

	var mine: Node2D = world.MINE_SCENE.instantiate() as Node2D

	if mine == null:
		return

	mine.name = "CollectibleMine"
	mine.z_index = 3
	mine.position = world._get_cell_center_position(cell, world._get_grid_layout())
	world.collectible_mines[cell] = mine
	world.add_child(mine)


static func pick_up_collectible_mine(world, cell: Vector2i) -> void:
	if not has_collectible_mine_at_cell(world, cell):
		return

	var mine: Node2D = world.collectible_mines[cell] as Node2D
	world.collectible_mines.erase(cell)
	world.available_mines += 1
	world._update_resource_labels()

	if mine != null and is_instance_valid(mine):
		mine.queue_free()


static func clear_collectible_mine_at_cell(world, cell: Vector2i) -> void:
	if not has_collectible_mine_at_cell(world, cell):
		return

	var mine: Node2D = world.collectible_mines[cell] as Node2D
	world.collectible_mines.erase(cell)

	if mine != null and is_instance_valid(mine):
		mine.queue_free()


static func spawn_mine_explosion_effect(world, cell: Vector2i, duration: float) -> void:
	var explosion: Node2D = world.MINE_EXPLOSION_SCENE.instantiate() as Node2D

	if explosion == null:
		return

	explosion.name = "MineExplosion"
	explosion.z_index = 6
	explosion.position = world._get_cell_center_position(cell, world._get_grid_layout())
	var explosive_level: int = world._get_upgrade_level("explosive")
	var scale_multiplier: float = 1.0 + float(explosive_level) * 0.15
	explosion.scale *= scale_multiplier
	world.add_child(explosion)
	world.active_explosion_effects.append(explosion)
	var tween: Tween = world.create_tween()
	world.active_move_tweens.append(tween)
	tween.tween_property(explosion, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(explosion, "queue_free"))


static func clear_explosion_effects(world) -> void:
	for effect in world.active_explosion_effects:
		if effect != null and is_instance_valid(effect):
			effect.queue_free()

	world.active_explosion_effects.clear()


static func get_blast_cells(world, center_cell: Vector2i) -> Array[Vector2i]:
	var blast_cells: Array[Vector2i] = []
	var blast_radius: int = world._get_mine_blast_radius()

	for y_offset in range(-blast_radius, blast_radius + 1):
		for x_offset in range(-blast_radius, blast_radius + 1):
			var cell: Vector2i = center_cell + Vector2i(x_offset, y_offset)

			if world._is_in_bounds(cell):
				blast_cells.append(cell)

	return blast_cells


static func trigger_mine_explosion(world, cell: Vector2i, duration: float) -> Array[int]:
	if not has_any_mine_at_cell(world, cell):
		return []

	if has_armed_mine_at_cell(world, cell):
		clear_active_mine(world, false)
	else:
		clear_collectible_mine_at_cell(world, cell)

	spawn_mine_explosion_effect(world, cell, duration)
	var blast_cells: Array[Vector2i] = get_blast_cells(world, cell)

	for blast_cell in blast_cells:
		destroy_rock_from_explosion(world, blast_cell)

	return world._get_red_ghost_indices_in_cells(blast_cells)


static func does_mine_explosion_hit_player(world, cell: Vector2i) -> bool:
	return get_blast_cells(world, cell).has(world.player_cell)


static func destroy_rock_from_explosion(world, cell: Vector2i) -> void:
	if not world._is_in_bounds(cell) or not world._is_cell_occupied(cell):
		return

	world._set_cell_occupied(cell, false)

	if world.rock_nodes.has(cell):
		var rock: Node2D = world.rock_nodes[cell] as Node2D
		world.rock_nodes.erase(cell)

		if rock != null:
			rock.queue_free()