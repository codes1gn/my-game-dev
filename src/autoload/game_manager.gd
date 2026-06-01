extends Node

const STATE_MAIN_MENU := 0
const STATE_DAILY_LIFE := 1
const STATE_INVESTIGATION := 2

var current_state: int = STATE_MAIN_MENU
var current_day: int = 1
var player_data: Dictionary = {}
var flags: Dictionary = {}
var next_dialogue_path: String = ""

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

func add_to_inventory(item_id: String) -> void:
	if item_id not in player_data["inventory"]:
		player_data["inventory"].append(item_id)
		EventBus.item_acquired.emit(item_id)

func has_item(item_id: String) -> bool:
	return item_id in player_data["inventory"]

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
