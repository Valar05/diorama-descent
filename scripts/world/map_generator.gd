extends RefCounted


static func initialize_map_state(world) -> void:
	world.map_state.clear()

	for row_index in range(world.MAP_HEIGHT):
		var row: Array = []
		row.resize(world.MAP_WIDTH)

		for column_index in range(world.MAP_WIDTH):
			row[column_index] = true

		world.map_state.append(row)

	generate_map(world)


static func generate_map(world) -> void:
	world.start_cell = Vector2i(world.rng.randi_range(1, world.MAP_WIDTH - 2), world.MAP_HEIGHT - 1)
	world.goal_cell = Vector2i(world.rng.randi_range(1, world.MAP_WIDTH - 2), 0)

	var critical_path: Array[Vector2i] = build_critical_path(world, world.start_cell, world.goal_cell)

	for cell in critical_path:
		world._set_cell_occupied(cell, false)

	var branch_cells: Array[Vector2i] = carve_branches(world, critical_path)
	carve_rooms(world, critical_path, branch_cells)


static func build_critical_path(world, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	for _attempt in range(world.PATH_BUILD_ATTEMPTS):
		var path: Array[Vector2i] = [start]
		var visited: Dictionary = {}
		visited[start] = true

		if extend_critical_path(world, start, goal, path, visited):
			return path

	return build_fallback_path(world, start, goal)


static func extend_critical_path(world, current: Vector2i, goal: Vector2i, path: Array[Vector2i], visited: Dictionary) -> bool:
	if current == goal:
		return path.size() >= world.MIN_CRITICAL_PATH_LENGTH

	if path.size() >= world.MAX_CRITICAL_PATH_LENGTH:
		return false

	var candidates: Array[Vector2i] = get_scored_neighbors(world, current, goal, visited, path)

	for next_cell in candidates:
		if next_cell == goal and path.size() + 1 < world.MIN_CRITICAL_PATH_LENGTH:
			continue

		visited[next_cell] = true
		path.append(next_cell)

		if extend_critical_path(world, next_cell, goal, path, visited):
			return true

		path.pop_back()
		visited.erase(next_cell)

	return false


static func get_scored_neighbors(world, current: Vector2i, goal: Vector2i, visited: Dictionary, path: Array[Vector2i]) -> Array[Vector2i]:
	var neighbor_scores: Array = []
	var previous_direction: Vector2i = Vector2i.ZERO

	if path.size() >= 2:
		previous_direction = current - path[path.size() - 2]

	for direction in world._get_cardinal_directions():
		var next_cell: Vector2i = current + direction

		if not world._is_in_bounds(next_cell):
			continue

		if visited.has(next_cell):
			continue

		var score: float = float(world._manhattan_distance(next_cell, goal)) * 2.0
		var edge_penalty: float = 0.0

		if next_cell.x == 0 or next_cell.x == world.MAP_WIDTH - 1:
			edge_penalty = 1.5

		var straight_penalty: float = 0.0

		if previous_direction != Vector2i.ZERO and direction == previous_direction:
			straight_penalty = 0.75

		var future_options: int = count_future_options(world, next_cell, visited)
		var freedom_bonus: float = float(future_options) * -0.5
		var random_jitter: float = world.rng.randf_range(0.0, 1.5)

		score += edge_penalty + straight_penalty + random_jitter + freedom_bonus
		neighbor_scores.append({"cell": next_cell, "score": score})

	neighbor_scores.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left["score"] < right["score"]
	)

	var ordered_neighbors: Array[Vector2i] = []

	for neighbor_score in neighbor_scores:
		ordered_neighbors.append(neighbor_score["cell"])

	return ordered_neighbors


static func count_future_options(world, cell: Vector2i, visited: Dictionary) -> int:
	var options: int = 0

	for direction in world._get_cardinal_directions():
		var next_cell: Vector2i = cell + direction

		if not world._is_in_bounds(next_cell):
			continue

		if visited.has(next_cell):
			continue

		options += 1

	return options


static func build_fallback_path(world, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var current: Vector2i = start
	var horizontal_direction: int = 1

	if goal.x < start.x:
		horizontal_direction = -1

	while current.y > goal.y:
		var target_x: int = current.x + horizontal_direction * world.rng.randi_range(0, 1)
		target_x = clampi(target_x, 1, world.MAP_WIDTH - 2)

		while current.x != target_x:
			current.x += horizontal_direction
			path.append(current)

		current.y -= 1
		path.append(current)

		if current.x == world.MAP_WIDTH - 2:
			horizontal_direction = -1
		elif current.x == 1:
			horizontal_direction = 1

	while current.x != goal.x:
		if current.x < goal.x:
			current.x += 1
		else:
			current.x -= 1

		path.append(current)

	return path


static func carve_branches(world, critical_path: Array[Vector2i]) -> Array[Vector2i]:
	var all_branch_cells: Array[Vector2i] = []
	var anchor_cells: Array[Vector2i] = critical_path.duplicate()

	if anchor_cells.size() > 2:
		anchor_cells.remove_at(anchor_cells.size() - 1)
		anchor_cells.remove_at(0)

	world._shuffle_cells(anchor_cells)

	var branch_target: int = world.rng.randi_range(world.MIN_BRANCH_COUNT, world.MAX_BRANCH_COUNT)
	var branches_created: int = 0

	for anchor_cell in anchor_cells:
		if branches_created >= branch_target:
			break

		var branch_length: int = world.rng.randi_range(world.MIN_BRANCH_LENGTH, world.MAX_BRANCH_LENGTH)
		var branch: Array[Vector2i] = build_branch(world, anchor_cell, branch_length)

		if branch.size() < world.MIN_BRANCH_LENGTH:
			continue

		for cell in branch:
			world._set_cell_occupied(cell, false)
			all_branch_cells.append(cell)

		branches_created += 1

	return all_branch_cells


static func build_branch(world, anchor_cell: Vector2i, target_length: int) -> Array[Vector2i]:
	var branch: Array[Vector2i] = []
	var current: Vector2i = anchor_cell
	var local_visited: Dictionary = {}
	local_visited[anchor_cell] = true

	for _step in range(target_length):
		var candidates: Array = []

		for direction in world._get_cardinal_directions():
			var next_cell: Vector2i = current + direction

			if not world._is_in_bounds(next_cell):
				continue

			if local_visited.has(next_cell):
				continue

			if not world._is_cell_occupied(next_cell):
				continue

			if world._count_open_neighbors(next_cell) > 1:
				continue

			var candidate_score: float = world.rng.randf_range(0.0, 1.0) - float(world._count_surrounding_rocks(next_cell)) * 0.15
			candidates.append({"cell": next_cell, "score": candidate_score})

		if candidates.is_empty():
			break

		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return left["score"] < right["score"]
		)
		var next_cell_data: Dictionary = candidates[0]
		var chosen_cell: Vector2i = next_cell_data["cell"]
		branch.append(chosen_cell)
		local_visited[chosen_cell] = true
		current = chosen_cell

	return branch


static func carve_rooms(world, critical_path: Array[Vector2i], branch_cells: Array[Vector2i]) -> void:
	var room_anchors: Array[Vector2i] = []

	for index in range(1, critical_path.size() - 1):
		room_anchors.append(critical_path[index])

	for cell in branch_cells:
		room_anchors.append(cell)

	world._shuffle_cells(room_anchors)

	var room_target: int = world.rng.randi_range(world.MIN_ROOM_COUNT, world.MAX_ROOM_COUNT)
	var rooms_created: int = 0

	for anchor_cell in room_anchors:
		if rooms_created >= room_target:
			break

		var room_size: Vector2i = Vector2i(2, 2)

		if world.rng.randf() < 0.3:
			room_size = Vector2i(2, 3)

		if carve_room(world, anchor_cell, room_size):
			rooms_created += 1


static func carve_room(world, anchor_cell: Vector2i, room_size: Vector2i) -> bool:
	var candidate_origins: Array[Vector2i] = []

	for offset_y in range(room_size.y):
		for offset_x in range(room_size.x):
			var origin: Vector2i = anchor_cell - Vector2i(offset_x, offset_y)
			var room_rect: Rect2i = Rect2i(origin, room_size)

			if room_rect.position.x < 0:
				continue

			if room_rect.position.y < 0:
				continue

			if room_rect.end.x > world.MAP_WIDTH:
				continue

			if room_rect.end.y > world.MAP_HEIGHT:
				continue

			candidate_origins.append(origin)

	if candidate_origins.is_empty():
		return false

	world._shuffle_cells(candidate_origins)

	for origin in candidate_origins:
		var carved_new_cells: int = 0

		for row_offset in range(room_size.y):
			for column_offset in range(room_size.x):
				var cell: Vector2i = origin + Vector2i(column_offset, row_offset)

				if world._is_cell_occupied(cell):
					carved_new_cells += 1

		if carved_new_cells == 0:
			continue

		for row_offset in range(room_size.y):
			for column_offset in range(room_size.x):
				var cell: Vector2i = origin + Vector2i(column_offset, row_offset)
				world._set_cell_occupied(cell, false)

		return true

	return false