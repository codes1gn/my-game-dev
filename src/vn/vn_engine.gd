extends Control

@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var choice_panel: VBoxContainer = $ChoicePanel
@onready var background: TextureRect = $Background
@onready var portrait_left: TextureRect = $PortraitLeft
@onready var portrait_right: TextureRect = $PortraitRight

var _dialogue_data: Dictionary = {}
var _nodes: Dictionary = {}
var _current_node_id: String = ""

var _pending_dialogue_path: String = ""

func _ready() -> void:
	_apply_theme()
	dialogue_box.advance_requested.connect(_on_advance)
	choice_panel.choice_selected.connect(_on_choice_selected)
	choice_panel.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	if not _pending_dialogue_path.is_empty():
		start_dialogue(_pending_dialogue_path)
	else:
		start_dialogue("res://data/dialogue/case_001_opening.json")

func _apply_theme() -> void:
	var bg_tex := ThemeManager.load_external_image("res://assets/scenes/bg_interrogation.jpg")
	if bg_tex:
		background.texture = bg_tex
	else:
		background.texture = ThemeManager.generate_gradient_bg(1280, 720, Color(0.04, 0.04, 0.07), Color(0.08, 0.06, 0.04))

	var box_style := ThemeManager.make_panel_style(
		Color(0.04, 0.04, 0.06, 0.88),
		ThemeManager.COLORS["accent_gold_dim"], 8
	)
	box_style.content_margin_left = 24
	box_style.content_margin_right = 24
	box_style.content_margin_top = 16
	box_style.content_margin_bottom = 16
	dialogue_box.add_theme_stylebox_override("panel", box_style)

func start_dialogue(dialogue_path: String) -> void:
	print("[VN] Loading dialogue: ", dialogue_path)
	_dialogue_data = GameManager.load_json(dialogue_path)
	if _dialogue_data == null:
		push_error("[VN] Failed to load dialogue: " + dialogue_path)
		return
	print("[VN] Loaded OK, nodes count: ", (_dialogue_data.get("nodes", []) as Array).size())
	_nodes.clear()
	for node_data in _dialogue_data.get("nodes", []):
		_nodes[node_data["id"]] = node_data
	_current_node_id = _dialogue_data.get("start_node", "start")
	EventBus.dialogue_started.emit(_dialogue_data.get("id", ""))
	_process_node()

func _process_node() -> void:
	if _current_node_id.is_empty() or _current_node_id not in _nodes:
		_end_dialogue()
		return

	var node: Dictionary = _nodes[_current_node_id]
	var node_type: String = node.get("type", "text")

	EventBus.dialogue_node_reached.emit(_current_node_id)

	match node_type:
		"text":
			_handle_text_node(node)
		"choice":
			_handle_choice_node(node)
		"condition":
			_handle_condition_node(node)
		"set_flag":
			_handle_set_flag_node(node)
		"end":
			_end_dialogue()

func _handle_text_node(node: Dictionary) -> void:
	var speaker: String = node.get("speaker", "")
	var text: String = node.get("text", "")
	var display_name := _get_speaker_display_name(speaker)

	_update_portraits(node)
	dialogue_box.show_dialogue(display_name, text)

	if node.has("set_flag"):
		GameManager.set_flag(node["set_flag"], node.get("flag_value", true))

func _handle_choice_node(node: Dictionary) -> void:
	var options: Array = node.get("options", [])
	var filtered: Array = []
	for opt in options:
		if _check_condition(opt.get("condition", null)):
			filtered.append(opt)
	if filtered.is_empty():
		_current_node_id = node.get("fallback", "")
		_process_node()
		return
	dialogue_box.hide_box()
	choice_panel.show_choices(filtered)

func _handle_condition_node(node: Dictionary) -> void:
	var checks: Array = node.get("branches", [])
	for branch in checks:
		if _check_condition(branch.get("condition", null)):
			_current_node_id = branch.get("next", "")
			_process_node()
			return
	_current_node_id = node.get("fallback", "")
	_process_node()

func _handle_set_flag_node(node: Dictionary) -> void:
	var flag_name: String = node.get("flag", "")
	var value: Variant = node.get("value", true)
	GameManager.set_flag(flag_name, value)
	_current_node_id = node.get("next", "")
	_process_node()

func _check_condition(cond) -> bool:
	if cond == null:
		return true
	if cond is Dictionary:
		for key: String in cond:
			if key.ends_with("_gte"):
				var attr_name: String = key.trim_suffix("_gte")
				if key.begins_with("system_points"):
					if GameManager.player_data["system_points"] < cond[key]:
						return false
				elif GameManager.get_attribute(attr_name) < cond[key]:
					return false
			elif key == "has_flag":
				if not GameManager.get_flag(cond[key]):
					return false
			elif key == "not_flag":
				if GameManager.get_flag(cond[key]):
					return false
			elif key == "has_item":
				if not GameManager.has_item(cond[key]):
					return false
		return true
	return true

func _on_advance() -> void:
	var node: Dictionary = _nodes.get(_current_node_id, {})
	_current_node_id = node.get("next", "")
	_process_node()

func _on_choice_selected(index: int) -> void:
	var node: Dictionary = _nodes.get(_current_node_id, {})
	var options: Array = node.get("options", [])
	var filtered: Array = []
	for opt in options:
		if _check_condition(opt.get("condition", null)):
			filtered.append(opt)
	if index < filtered.size():
		var selected: Dictionary = filtered[index]
		EventBus.choice_made.emit(_current_node_id, index)
		if selected.has("set_flag"):
			GameManager.set_flag(selected["set_flag"], selected.get("flag_value", true))
		_current_node_id = selected.get("next", "")
		_process_node()

func _end_dialogue() -> void:
	dialogue_box.hide_box()
	choice_panel.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	EventBus.dialogue_ended.emit(_dialogue_data.get("id", ""))

	var next_scene: String = _dialogue_data.get("on_end_goto", "")
	if not next_scene.is_empty():
		_transition_to(next_scene)
	else:
		_show_end_screen()

func _transition_to(scene_path: String) -> void:
	var label := Label.new()
	label.text = "正在进入现场..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.anchors_preset = Control.PRESET_FULL_RECT
	add_child(label)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file(scene_path)

func _show_end_screen() -> void:
	var label := Label.new()
	label.text = "\u2014 \u5e8f\u7ae0\u5b8c \u2014\n\u6309\u4efb\u610f\u952e\u8fd4\u56de\u4e3b\u83dc\u5355"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.anchors_preset = Control.PRESET_FULL_RECT
	add_child(label)
	await get_tree().create_timer(1.0).timeout
	set_process_unhandled_input(true)
	_waiting_for_return = true

var _waiting_for_return: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_return and event.is_pressed():
		get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _get_speaker_display_name(speaker_id: String) -> String:
	var char_path := "res://data/characters/%s.json" % speaker_id
	var char_data = GameManager.load_json(char_path)
	if char_data != null:
		return char_data.get("name", speaker_id)
	return speaker_id

var _portrait_cache: Dictionary = {}
const _PORTRAIT_MAP := {
	"陈益": "res://assets/portraits/chen_yi.jpg",
	"chen_yi": "res://assets/portraits/chen_yi.jpg",
	"周业斌": "res://assets/portraits/zhou_yebin.jpg",
	"zhou_yebin": "res://assets/portraits/zhou_yebin.jpg",
	"青年警员": "res://assets/portraits/young_officer.jpg",
	"法医": "res://assets/portraits/forensic_doctor.jpg",
	"助手": "res://assets/portraits/assistant_officer.jpg",
}

func _update_portraits(node: Dictionary) -> void:
	if node.has("portrait_left") or node.has("portrait_right"):
		_update_portrait_explicit(node)
		return

	var speaker: String = node.get("speaker", "")
	if speaker == "narrator" or speaker.is_empty():
		portrait_left.visible = false
		portrait_right.visible = false
		return

	var is_protagonist := speaker == "陈益" or speaker == "chen_yi"
	var portrait_path: String = _PORTRAIT_MAP.get(speaker, "")

	if portrait_path.is_empty():
		portrait_left.visible = false
		portrait_right.visible = false
		return

	var tex: Texture2D = _load_portrait(portrait_path)
	if tex == null:
		portrait_left.visible = false
		portrait_right.visible = false
		return

	if is_protagonist:
		portrait_left.texture = tex
		portrait_left.visible = true
		portrait_right.modulate = Color(0.5, 0.5, 0.5, 0.6) if portrait_right.visible else Color.WHITE
		portrait_left.modulate = Color.WHITE
	else:
		portrait_right.texture = tex
		portrait_right.visible = true
		portrait_left.modulate = Color(0.5, 0.5, 0.5, 0.6) if portrait_left.visible else Color.WHITE
		portrait_right.modulate = Color.WHITE

func _update_portrait_explicit(node: Dictionary) -> void:
	if node.has("portrait_left"):
		var p: String = node["portrait_left"]
		if p.is_empty():
			portrait_left.visible = false
		else:
			portrait_left.texture = _load_portrait(p)
			portrait_left.visible = portrait_left.texture != null
	if node.has("portrait_right"):
		var p: String = node["portrait_right"]
		if p.is_empty():
			portrait_right.visible = false
		else:
			portrait_right.texture = _load_portrait(p)
			portrait_right.visible = portrait_right.texture != null

func _load_portrait(p: String) -> Texture2D:
	if p in _portrait_cache:
		return _portrait_cache[p]
	var tex: Texture2D = ThemeManager.load_external_image(p)
	if tex:
		_portrait_cache[p] = tex
		return tex
	return null
