extends RefCounted


static func ensure_crystal_ui(world) -> void:
	if world.crystal_ui_layer != null:
		return

	world.crystal_ui_layer = CanvasLayer.new()
	world.crystal_ui_layer.name = "CrystalUI"
	world.crystal_ui_layer.layer = 8
	world.add_child(world.crystal_ui_layer)

	world.crystal_ui_root = Control.new()
	world.crystal_ui_root.name = "CrystalUIRoot"
	world.crystal_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.crystal_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.crystal_ui_root.offset_left = 0.0
	world.crystal_ui_root.offset_top = 0.0
	world.crystal_ui_root.offset_right = 0.0
	world.crystal_ui_root.offset_bottom = 0.0
	world.crystal_ui_layer.add_child(world.crystal_ui_root)

	world.crystal_label = Label.new()
	world.crystal_label.name = "CrystalLabel"
	world.crystal_label.text = "Crystal: 0"
	world.crystal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	world.crystal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world.crystal_label.add_theme_font_override("font", world.RYE_FONT)
	world.crystal_label.add_theme_font_size_override("font_size", 64)
	world.crystal_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	world.crystal_label.offset_left = -420.0
	world.crystal_label.offset_top = 24.0
	world.crystal_label.offset_right = -24.0
	world.crystal_label.offset_bottom = 108.0
	world.crystal_ui_root.add_child(world.crystal_label)

	world.mine_count_label = Label.new()
	world.mine_count_label.name = "MineCountLabel"
	world.mine_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	world.mine_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world.mine_count_label.add_theme_font_override("font", world.RYE_FONT)
	world.mine_count_label.add_theme_font_size_override("font_size", 40)
	world.mine_count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	world.mine_count_label.offset_left = -420.0
	world.mine_count_label.offset_top = 104.0
	world.mine_count_label.offset_right = -24.0
	world.mine_count_label.offset_bottom = 150.0
	world.crystal_ui_root.add_child(world.mine_count_label)

	world.shovel_count_label = Label.new()
	world.shovel_count_label.name = "ShovelCountLabel"
	world.shovel_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	world.shovel_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world.shovel_count_label.add_theme_font_override("font", world.RYE_FONT)
	world.shovel_count_label.add_theme_font_size_override("font_size", 40)
	world.shovel_count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	world.shovel_count_label.offset_left = -420.0
	world.shovel_count_label.offset_top = 148.0
	world.shovel_count_label.offset_right = -24.0
	world.shovel_count_label.offset_bottom = 194.0
	world.crystal_ui_root.add_child(world.shovel_count_label)

	world.crystal_popup_root = Control.new()
	world.crystal_popup_root.name = "CrystalPopupRoot"
	world.crystal_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.crystal_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.crystal_popup_root.offset_left = 0.0
	world.crystal_popup_root.offset_top = 0.0
	world.crystal_popup_root.offset_right = 0.0
	world.crystal_popup_root.offset_bottom = 0.0
	world.crystal_ui_root.add_child(world.crystal_popup_root)

	update_resource_labels(world)


static func update_crystal_label(world) -> void:
	if world.crystal_label == null:
		return

	world.crystal_label.text = "Crystal: %d" % world.crystal_total


static func update_resource_labels(world) -> void:
	update_crystal_label(world)

	if world.mine_count_label != null:
		world.mine_count_label.text = "Mines: %d" % world.available_mines

	if world.shovel_count_label != null:
		world.shovel_count_label.text = "Shovels: %d" % world.available_shovel_fists


static func clear_crystal_popups(world) -> void:
	for popup in world.active_crystal_popups:
		if popup != null and is_instance_valid(popup):
			popup.queue_free()

	world.active_crystal_popups.clear()


static func clear_crystals(world) -> void:
	for crystal_node in world.crystal_nodes.values():
		var node: Node2D = crystal_node as Node2D

		if node != null and is_instance_valid(node):
			node.queue_free()

	world.crystal_nodes.clear()
	world.crystal_values.clear()
	clear_crystal_popups(world)


static func spawn_map_crystals(world) -> void:
	clear_crystals(world)
	var candidate_cells: Array[Vector2i] = []

	for row_index in range(world.MAP_HEIGHT):
		for column_index in range(world.MAP_WIDTH):
			var cell: Vector2i = Vector2i(column_index, row_index)

			if world._is_cell_occupied(cell):
				candidate_cells.append(cell)

	if candidate_cells.is_empty():
		return

	world._shuffle_cells(candidate_cells)
	spawn_crystal(world, candidate_cells[0], world.CRYSTAL_BIG_SCENE, 3, "CrystalBig")

	var small_crystal_count: int = world.rng.randi_range(world.MIN_SMALL_CRYSTALS_PER_MAP, world.MAX_SMALL_CRYSTALS_PER_MAP)
	var small_scenes: Array[PackedScene] = [world.CRYSTAL_SMALL_1_SCENE, world.CRYSTAL_SMALL_2_SCENE]

	for index in range(1, mini(candidate_cells.size(), small_crystal_count + 1)):
		var scene_index: int = world.rng.randi_range(0, small_scenes.size() - 1)
		spawn_crystal(world, candidate_cells[index], small_scenes[scene_index], 1, "CrystalSmall")


static func spawn_crystal(world, cell: Vector2i, scene: PackedScene, value: int, crystal_name: String) -> void:
	if world.crystal_nodes.has(cell):
		return

	if world._is_cell_occupied(cell):
		world._set_cell_occupied(cell, false)

		if world.rock_nodes.has(cell):
			var rock: Node2D = world.rock_nodes[cell] as Node2D
			world.rock_nodes.erase(cell)

			if rock != null and is_instance_valid(rock):
				rock.queue_free()

	var crystal: Node2D = scene.instantiate() as Node2D

	if crystal == null:
		return

	crystal.name = crystal_name
	crystal.z_index = 2
	crystal.position = world._get_cell_center_position(cell, world._get_grid_layout())
	world.add_child(crystal)
	world.crystal_nodes[cell] = crystal
	world.crystal_values[cell] = value


static func has_crystal_at_cell(world, cell: Vector2i) -> bool:
	return world.crystal_nodes.has(cell)


static func collect_crystal_at_cell(world, cell: Vector2i) -> int:
	if not world.crystal_nodes.has(cell):
		return 0

	var crystal_node: Node2D = world.crystal_nodes[cell] as Node2D
	var crystal_value: int = world.crystal_values[cell]
	world.crystal_nodes.erase(cell)
	world.crystal_values.erase(cell)

	if crystal_node != null and is_instance_valid(crystal_node):
		crystal_node.queue_free()

	world.crystal_total += crystal_value
	update_resource_labels(world)
	show_crystal_popup(world, cell, crystal_value)
	return crystal_value


static func show_crystal_popup(world, cell: Vector2i, crystal_value: int) -> void:
	if world.crystal_popup_root == null:
		return

	var popup: Label = Label.new()
	popup.name = "CrystalPopup"
	popup.text = "+%d" % crystal_value
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_override("font", world.RYE_FONT)
	popup.add_theme_font_size_override("font_size", 72)
	popup.modulate = Color(0.85, 1.0, 1.0, 1.0)
	popup.scale = Vector2.ONE * 0.6
	world.crystal_popup_root.add_child(popup)

	var popup_size: Vector2 = popup.get_combined_minimum_size()
	popup.size = popup_size
	popup.pivot_offset = popup_size / 2.0
	var start_position: Vector2 = world._get_cell_center_position(cell, world._get_grid_layout()) - popup_size / 2.0
	popup.position = start_position
	world.active_crystal_popups.append(popup)

	var tween: Tween = world.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2.ONE * 1.25, world.CRYSTAL_POPUP_GROW_DURATION)
	tween.parallel().tween_property(popup, "position", start_position + Vector2(0.0, -10.0), world.CRYSTAL_POPUP_GROW_DURATION)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(popup, "scale", Vector2.ONE * 0.75, world.CRYSTAL_POPUP_FADE_DURATION)
	tween.parallel().tween_property(popup, "position", start_position + Vector2(0.0, -world.CRYSTAL_POPUP_RISE_DISTANCE), world.CRYSTAL_POPUP_FADE_DURATION)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, world.CRYSTAL_POPUP_FADE_DURATION)
	tween.tween_callback(Callable(popup, "queue_free"))