extends RefCounted


static func ensure_shop_ui(world) -> void:
	if world.shop_layer != null:
		return

	world.shop_layer = CanvasLayer.new()
	world.shop_layer.name = "ShopUI"
	world.shop_layer.layer = 9
	world.add_child(world.shop_layer)

	world.shop_root = Control.new()
	world.shop_root.name = "ShopRoot"
	world.shop_root.visible = false
	world.shop_root.mouse_filter = Control.MOUSE_FILTER_STOP
	world.shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.shop_root.offset_left = 0.0
	world.shop_root.offset_top = 0.0
	world.shop_root.offset_right = 0.0
	world.shop_root.offset_bottom = 0.0
	world.shop_layer.add_child(world.shop_root)

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.07, 0.05, 0.03, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	world.shop_root.add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	world.shop_root.add_child(center)

	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(940.0, 860.0)
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.92, 0.85, 0.69, 0.98)
	frame_style.border_color = Color(0.24, 0.13, 0.04, 1.0)
	frame_style.set_border_width_all(6)
	frame_style.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(frame)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.custom_minimum_size = Vector2(880.0, 800.0)
	frame.add_child(content)

	var title: Label = Label.new()
	title.text = "Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", world.RYE_FONT)
	title.add_theme_font_size_override("font_size", 72)
	content.add_child(title)

	world.shop_crystal_label = Label.new()
	world.shop_crystal_label.name = "ShopCrystalLabel"
	world.shop_crystal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world.shop_crystal_label.add_theme_font_override("font", world.RYE_FONT)
	world.shop_crystal_label.add_theme_font_size_override("font_size", 42)
	content.add_child(world.shop_crystal_label)

	var placeholder_row: HBoxContainer = HBoxContainer.new()
	placeholder_row.alignment = BoxContainer.ALIGNMENT_CENTER
	placeholder_row.add_theme_constant_override("separation", 24)
	content.add_child(placeholder_row)
	world.shop_upgrade_buttons.clear()

	for index in range(3):
		var upgrade_button: Button = Button.new()
		upgrade_button.name = "UpgradeButton%d" % index
		upgrade_button.custom_minimum_size = Vector2(248.0, 220.0)
		upgrade_button.add_theme_font_override("font", world.RYE_FONT)
		upgrade_button.add_theme_font_size_override("font_size", 24)
		upgrade_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_button.pressed.connect(Callable(world, "_on_shop_upgrade_pressed").bind(index))
		placeholder_row.add_child(upgrade_button)
		world.shop_upgrade_buttons.append(upgrade_button)

	var purchase_row: HBoxContainer = HBoxContainer.new()
	purchase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	purchase_row.add_theme_constant_override("separation", 32)
	content.add_child(purchase_row)

	world.shop_mine_button = Button.new()
	world.shop_mine_button.name = "BuyMineButton"
	world.shop_mine_button.text = "Mine: 2"
	world.shop_mine_button.custom_minimum_size = Vector2(200.0, 200.0)
	world.shop_mine_button.add_theme_font_override("font", world.RYE_FONT)
	world.shop_mine_button.add_theme_font_size_override("font_size", 32)
	world.shop_mine_button.pressed.connect(world._on_shop_buy_mine_pressed)
	purchase_row.add_child(world.shop_mine_button)

	world.shop_shovel_button = Button.new()
	world.shop_shovel_button.name = "BuyShovelButton"
	world.shop_shovel_button.text = "Shovel: 1"
	world.shop_shovel_button.custom_minimum_size = Vector2(200.0, 200.0)
	world.shop_shovel_button.add_theme_font_override("font", world.RYE_FONT)
	world.shop_shovel_button.add_theme_font_size_override("font_size", 32)
	world.shop_shovel_button.pressed.connect(world._on_shop_buy_shovel_pressed)
	purchase_row.add_child(world.shop_shovel_button)

	world.shop_continue_button = Button.new()
	world.shop_continue_button.name = "NextFloorButton"
	world.shop_continue_button.text = "Next Floor"
	world.shop_continue_button.custom_minimum_size = Vector2(320.0, 112.0)
	world.shop_continue_button.add_theme_font_override("font", world.RYE_FONT)
	world.shop_continue_button.add_theme_font_size_override("font_size", 36)
	world.shop_continue_button.pressed.connect(world._on_shop_continue_pressed)
	content.add_child(world.shop_continue_button)

	update_shop_ui(world)


static func open_shop(world) -> void:
	update_shop_ui(world)
	if world.shop_root != null:
		world.shop_root.visible = true


static func close_shop(world) -> void:
	if world.shop_root != null:
		world.shop_root.visible = false


static func update_shop_ui(world) -> void:
	if world.shop_crystal_label != null:
		world.shop_crystal_label.text = "Crystal: %d" % world.crystal_total

	for index in range(world.shop_upgrade_buttons.size()):
		var upgrade_button: Button = world.shop_upgrade_buttons[index]

		if upgrade_button == null:
			continue

		upgrade_button.text = world._get_shop_upgrade_button_text(index)
		upgrade_button.disabled = world._is_shop_upgrade_disabled(index)

	if world.shop_mine_button != null:
		var mine_cost: int = world._get_shop_mine_cost()
		world.shop_mine_button.text = "Mine: %d" % mine_cost
		world.shop_mine_button.disabled = world.crystal_total < mine_cost

	if world.shop_shovel_button != null:
		var shovel_cost: int = world._get_shop_shovel_cost()
		world.shop_shovel_button.text = "Shovel: %d" % shovel_cost
		world.shop_shovel_button.disabled = world.crystal_total < shovel_cost


static func buy_mine(world) -> void:
	var cost: int = world._get_shop_mine_cost()

	if world.crystal_total < cost:
		return

	world.crystal_total -= cost
	world.available_mines += 1
	world._update_resource_labels()
	update_shop_ui(world)


static func buy_shovel(world) -> void:
	var cost: int = world._get_shop_shovel_cost()

	if world.crystal_total < cost:
		return

	world.crystal_total -= cost
	world.max_shovel_fists += 1
	world.available_shovel_fists += 1
	world._update_resource_labels()
	update_shop_ui(world)