extends Node

const STATE_MAIN_MENU := 0
const STATE_DAILY_LIFE := 1
const STATE_INVESTIGATION := 2

var current_state: int = STATE_MAIN_MENU
var current_day: int = 1
var player_data: Dictionary = {}
var flags: Dictionary = {}
var next_dialogue_path: String = ""

const BASE_TIME_BUDGET := 480  # 8 hours in minutes
var time_remaining: int = BASE_TIME_BUDGET
var time_budget_active: bool = false

func _ready() -> void:
	_init_player_data()

func _init_player_data() -> void:
	player_data = {
		"name": "陈益",
		"rank": 0,
		"system_points": 0,
		"attributes": {
			"observation": 5,
			"interrogation": 5,
			"forensics": 3,
			"psychology": 5,
			"fitness": 3,
			"charisma": 4,
		},
		"inventory": [],
		"unlocked_talents": [],
		"active_skills": [],
		"cases_solved": 0,
		"reputation": 50,
	}

func change_state(new_state: int) -> void:
	var old_state := current_state
	current_state = new_state
	EventBus.game_state_changed.emit(old_state, new_state)

func advance_day() -> void:
	current_day += 1
	EventBus.day_advanced.emit(current_day)

func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return flags.get(flag_name, default)

func add_system_points(amount: int) -> void:
	var old := player_data["system_points"] as int
	player_data["system_points"] = old + amount
	EventBus.system_points_changed.emit(old, old + amount)

func get_attribute(attr_name: String) -> int:
	return player_data["attributes"].get(attr_name, 0)

var _items_db: Dictionary = {}

func load_items_db() -> void:
	if not _items_db.is_empty():
		return
	var data: Variant = load_json("res://data/items.json")
	if data == null:
		return
	for item: Dictionary in data.get("items", []):
		_items_db[item["id"]] = item

func get_item_data(item_id: String) -> Dictionary:
	load_items_db()
	return _items_db.get(item_id, {})

func get_shop_items() -> Array[Dictionary]:
	load_items_db()
	var data: Variant = load_json("res://data/items.json")
	if data == null:
		return []
	var shop_ids: Array = data.get("shop", {}).get("available", [])
	var result: Array[Dictionary] = []
	for sid: String in shop_ids:
		if sid in _items_db:
			result.append(_items_db[sid])
	return result

func add_to_inventory(item_id: String) -> void:
	if item_id not in player_data["inventory"]:
		player_data["inventory"].append(item_id)
		EventBus.item_acquired.emit(item_id)

func remove_from_inventory(item_id: String) -> void:
	if item_id in player_data["inventory"]:
		player_data["inventory"].erase(item_id)

func has_item(item_id: String) -> bool:
	return item_id in player_data["inventory"]

func buy_item(item_id: String) -> bool:
	var item := get_item_data(item_id)
	if item.is_empty():
		return false
	var cost: int = item.get("cost", 0)
	var pts: int = player_data.get("system_points", 0)
	if pts < cost:
		return false
	if not item.get("consumable", false) and has_item(item_id):
		return false
	add_system_points(-cost)
	add_to_inventory(item_id)
	return true

func use_item(item_id: String) -> bool:
	if not has_item(item_id):
		return false
	var item := get_item_data(item_id)
	if item.get("consumable", false):
		remove_from_inventory(item_id)
	EventBus.item_used.emit(item_id)
	return true

func has_talent(talent_id: String) -> bool:
	return talent_id in player_data["unlocked_talents"]

func unlock_talent(talent_id: String) -> void:
	if talent_id not in player_data["unlocked_talents"]:
		player_data["unlocked_talents"].append(talent_id)

func has_skill(skill_id: String) -> bool:
	return skill_id in player_data["active_skills"]

func activate_skill(skill_id: String) -> void:
	if skill_id not in player_data["active_skills"]:
		player_data["active_skills"].append(skill_id)

func modify_attribute(attr_name: String, delta: int) -> void:
	var old_val: int = player_data["attributes"].get(attr_name, 0)
	var new_val := old_val + delta
	player_data["attributes"][attr_name] = new_val
	EventBus.attribute_changed.emit(attr_name, old_val, new_val)

func start_time_budget() -> void:
	var fitness_bonus := get_attribute("fitness") * 10  # each fitness point = 10 extra minutes
	time_remaining = BASE_TIME_BUDGET + fitness_bonus
	if has_skill("iron_man"):
		time_remaining += 120  # iron_man talent bonus
	time_budget_active = true

func spend_time(minutes: int) -> bool:
	if not time_budget_active:
		return true
	time_remaining = maxi(0, time_remaining - minutes)
	return time_remaining > 0

func get_time_display() -> String:
	var hours := time_remaining / 60
	var mins := time_remaining % 60
	return "%d:%02d" % [hours, mins]

func is_time_up() -> bool:
	return time_budget_active and time_remaining <= 0

func reset_time_budget() -> void:
	time_budget_active = false
	time_remaining = BASE_TIME_BUDGET

## Attribute check: roll d20 + attribute vs difficulty.
## Returns { passed: bool, roll: int, total: int, difficulty: int, margin: int }
func attribute_check(attr_name: String, difficulty: int) -> Dictionary:
	var attr_val: int = get_attribute(attr_name)
	var roll: int = randi_range(1, 20)
	var total: int = roll + attr_val
	var passed: bool = total >= difficulty
	var margin: int = total - difficulty
	return {
		"passed": passed,
		"roll": roll,
		"attribute": attr_val,
		"total": total,
		"difficulty": difficulty,
		"margin": margin,
		"attr_name": attr_name,
	}

## Simplified check: returns true/false based on attribute threshold.
## success_rate = clamp((attribute - threshold) * 15 + 50, 10, 95)
func soft_check(attr_name: String, threshold: int) -> Dictionary:
	var attr_val: int = get_attribute(attr_name)
	var success_rate: int = clampi((attr_val - threshold) * 15 + 50, 10, 95)
	var roll: int = randi_range(1, 100)
	var passed: bool = roll <= success_rate
	return {
		"passed": passed,
		"roll": roll,
		"success_rate": success_rate,
		"attribute": attr_val,
		"threshold": threshold,
		"attr_name": attr_name,
	}

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 3

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot

func save_game(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var save_data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"current_day": current_day,
		"current_state": current_state,
		"player_data": player_data,
		"flags": flags,
	}
	var path := _get_save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Save] Failed to write: " + path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_game(slot: int) -> bool:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[Save] Parse error: " + path)
		return false
	var data: Dictionary = json.data
	current_day = data.get("current_day", 1)
	current_state = data.get("current_state", STATE_MAIN_MENU)
	player_data = data.get("player_data", {})
	flags = data.get("flags", {})
	if not player_data.has("unlocked_talents"):
		player_data["unlocked_talents"] = []
	if not player_data.has("active_skills"):
		player_data["active_skills"] = []
	return true

func delete_save(slot: int) -> void:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_save_info(slot: int) -> Dictionary:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.data
	var pd: Dictionary = data.get("player_data", {})
	return {
		"slot": slot,
		"timestamp": data.get("timestamp", ""),
		"day": data.get("current_day", 1),
		"points": pd.get("system_points", 0),
		"cases_solved": pd.get("cases_solved", 0),
		"talents": (pd.get("unlocked_talents", []) as Array).size(),
		"items": (pd.get("inventory", []) as Array).size(),
	}

func has_any_save() -> bool:
	for i in range(MAX_SLOTS):
		if FileAccess.file_exists(_get_save_path(i)):
			return true
	return false

func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open: " + path)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
