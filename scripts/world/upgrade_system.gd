extends RefCounted


const UPGRADE_IDS: Array[String] = [
	"overtime",
	"charismatic",
	"flak_jacket",
	"influential",
	"booster",
	"explosive",
	"backpack",
	"forceful",
	"spiked_armor",
]

const UPGRADE_NAMES: Dictionary = {
	"overtime": "Overtime",
	"charismatic": "Charismatic",
	"flak_jacket": "Flak Jacket",
	"influential": "Influential",
	"booster": "Booster",
	"explosive": "Explosive",
	"backpack": "Backpack",
	"forceful": "Forceful",
	"spiked_armor": "Spiked Armor",
}


static func ensure_upgrade_state(world) -> void:
	if not world.upgrade_levels.is_empty():
		return

	for upgrade_id in UPGRADE_IDS:
		world.upgrade_levels[upgrade_id] = 0

	reset_turn_bonus_counters(world)
	reset_floor_upgrade_state(world)


static func get_upgrade_level(world, upgrade_id: String) -> int:
	if not world.upgrade_levels.has(upgrade_id):
		return 0

	return world.upgrade_levels[upgrade_id]


static func get_upgrade_name(upgrade_id: String) -> String:
	if UPGRADE_NAMES.has(upgrade_id):
		return UPGRADE_NAMES[upgrade_id]

	return upgrade_id.capitalize()


static func get_discounted_cost(world, base_cost: int) -> int:
	if base_cost > 1 and get_upgrade_level(world, "charismatic") > 0:
		return max(1, base_cost - 1)

	return base_cost


static func get_upgrade_base_cost(world, upgrade_id: String) -> int:
	match upgrade_id:
		"overtime":
			if get_upgrade_level(world, upgrade_id) <= 0:
				return 3
			return 4
		"charismatic":
			return 4
		"flak_jacket":
			return 3
		"influential":
			return 3
		"booster":
			return 5
		"explosive":
			return 3
		"backpack":
			return 3
		"forceful":
			return 3
		"spiked_armor":
			return 5

	return 3


static func get_upgrade_cost(world, upgrade_id: String) -> int:
	return get_discounted_cost(world, get_upgrade_base_cost(world, upgrade_id))


static func can_upgrade_be_offered(world, upgrade_id: String) -> bool:
	match upgrade_id:
		"charismatic":
			return get_upgrade_level(world, upgrade_id) <= 0

	return true


static func roll_shop_upgrades(world) -> void:
	ensure_upgrade_state(world)
	var available_ids: Array[String] = []

	for upgrade_id in UPGRADE_IDS:
		if can_upgrade_be_offered(world, upgrade_id):
			available_ids.append(upgrade_id)

	for index in range(available_ids.size() - 1, 0, -1):
		var swap_index: int = world.rng.randi_range(0, index)
		var cached_id: String = available_ids[index]
		available_ids[index] = available_ids[swap_index]
		available_ids[swap_index] = cached_id

	world.current_shop_upgrades.clear()

	for index in range(mini(3, available_ids.size())):
		world.current_shop_upgrades.append(available_ids[index])


static func get_offer_text(world, offer_index: int) -> String:
	if offer_index < 0 or offer_index >= world.current_shop_upgrades.size():
		return "Sold Out"

	var upgrade_id: String = world.current_shop_upgrades[offer_index]
	var cost: int = get_upgrade_cost(world, upgrade_id)
	return "%s\n%s\n%d Crystal" % [
		get_upgrade_name(upgrade_id),
		get_upgrade_summary(world, upgrade_id),
		cost,
	]


static func is_offer_disabled(world, offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= world.current_shop_upgrades.size():
		return true

	var upgrade_id: String = world.current_shop_upgrades[offer_index]

	if not can_upgrade_be_offered(world, upgrade_id):
		return true

	return world.crystal_total < get_upgrade_cost(world, upgrade_id)


static func buy_shop_upgrade(world, offer_index: int) -> void:
	if offer_index < 0 or offer_index >= world.current_shop_upgrades.size():
		return

	var upgrade_id: String = world.current_shop_upgrades[offer_index]

	if not can_upgrade_be_offered(world, upgrade_id):
		return

	var cost: int = get_upgrade_cost(world, upgrade_id)

	if world.crystal_total < cost:
		return

	world.crystal_total -= cost
	apply_upgrade_purchase(world, upgrade_id)
	world._update_resource_labels()


static func apply_upgrade_purchase(world, upgrade_id: String) -> void:
	var level: int = get_upgrade_level(world, upgrade_id)

	match upgrade_id:
		"charismatic":
			world.upgrade_levels[upgrade_id] = 1
		"influential":
			world.upgrade_levels[upgrade_id] = level + 1
			world.influence_reach = world.DEFAULT_INFLUENCE_REACH + world.upgrade_levels[upgrade_id]
		_:
			world.upgrade_levels[upgrade_id] = level + 1


static func get_upgrade_summary(world, upgrade_id: String) -> String:
	var next_level: int = get_upgrade_level(world, upgrade_id) + 1

	match upgrade_id:
		"overtime":
			return "Free mines/turn: %d" % next_level
		"charismatic":
			return "Shop costs over 1: -1"
		"flak_jacket":
			return "Ignore mine hits/floor: %d" % next_level
		"influential":
			return "Influence range: %d" % (world.DEFAULT_INFLUENCE_REACH + next_level)
		"booster":
			return "Free moves/turn: %d" % next_level
		"explosive":
			return "Mine blast radius: %d" % (1 + next_level)
		"backpack":
			return "Floor-start shovels: +%d" % next_level
		"forceful":
			return "Shovel push tiles: %d" % (world.SHOVEL_FIST_MAX_PUSH_TILES + next_level)
		"spiked_armor":
			return "Ghost hits killed/floor: %d" % next_level

	return "Upgrade"


static func reset_turn_bonus_counters(world) -> void:
	world.free_mines_remaining = get_upgrade_level(world, "overtime")
	world.free_moves_remaining = get_upgrade_level(world, "booster")


static func reset_floor_upgrade_state(world) -> void:
	ensure_upgrade_state(world)
	world.influence_reach = world.DEFAULT_INFLUENCE_REACH + get_upgrade_level(world, "influential")
	world.floor_ignored_mine_hits_remaining = get_upgrade_level(world, "flak_jacket")
	world.floor_spiked_armor_hits_remaining = get_upgrade_level(world, "spiked_armor")
	world.available_shovel_fists = world.max_shovel_fists + get_upgrade_level(world, "backpack")
	reset_turn_bonus_counters(world)


static func consume_free_move_charge(world) -> bool:
	if world.free_moves_remaining <= 0:
		return false

	world.free_moves_remaining -= 1
	return true


static func consume_free_mine_charge(world) -> bool:
	if world.free_mines_remaining <= 0:
		return false

	world.free_mines_remaining -= 1
	return true


static func get_mine_blast_radius(world) -> int:
	return 1 + get_upgrade_level(world, "explosive")


static func try_ignore_mine_damage(world) -> bool:
	if world.floor_ignored_mine_hits_remaining <= 0:
		return false

	world.floor_ignored_mine_hits_remaining -= 1
	return true


static func get_shovel_push_distance(world) -> int:
	return world.SHOVEL_FIST_MAX_PUSH_TILES + get_upgrade_level(world, "forceful")


static func resolve_spiked_armor_collisions(world, colliding_indices: Array[int]) -> bool:
	if colliding_indices.is_empty() or world.floor_spiked_armor_hits_remaining <= 0:
		return false

	var kill_count: int = mini(world.floor_spiked_armor_hits_remaining, colliding_indices.size())
	var killed_indices: Array[int] = []

	for index in range(kill_count):
		killed_indices.append(colliding_indices[index])

	world.floor_spiked_armor_hits_remaining -= kill_count
	world._remove_red_ghosts_by_indices(killed_indices)
	return kill_count >= colliding_indices.size()