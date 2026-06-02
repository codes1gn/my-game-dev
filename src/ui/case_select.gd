extends Control

var _cases: Array = []

func _ready() -> void:
	_apply_theme()
	AudioManager.play_bgm("menu")
	_load_cases()
	_build_ui()

func _apply_theme() -> void:
	var bg_tex := ThemeManager.load_external_image("res://assets/scenes/bg_main_menu.jpg")
	if bg_tex:
		$Background.texture = bg_tex
	else:
		$Background.texture = ThemeManager.generate_vignette_bg(1280, 720, Color(0.03, 0.03, 0.06))
	$Background.expand_mode = 1
	$Background.stretch_mode = 6
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _load_cases() -> void:
	var data = GameManager.load_json("res://data/cases/case_index.json")
	if data and data.has("cases"):
		_cases = data["cases"]

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "选择案件"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for i in range(_cases.size()):
		var case_data: Dictionary = _cases[i]
		_add_case_card(list, case_data, i)

	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.custom_minimum_size = Vector2(200, 44)
	ThemeManager.style_button(back_btn)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/ui/main_menu.tscn"))
	vbox.add_child(back_btn)

func _add_case_card(parent: VBoxContainer, case_data: Dictionary, index: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var playable: bool = case_data.get("status", "") == "playable"
	var bg_color := Color(0.08, 0.08, 0.12, 0.9) if playable else Color(0.05, 0.05, 0.08, 0.6)
	var border_color := ThemeManager.COLORS["accent_gold_dim"] if playable else Color(0.3, 0.3, 0.3, 0.4)
	var style := ThemeManager.make_panel_style(bg_color, border_color, 6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var diff_label := Label.new()
	var stars := ""
	for s in range(case_data.get("difficulty", 1)):
		stars += "★"
	diff_label.text = stars
	diff_label.add_theme_font_size_override("font_size", 20)
	diff_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"] if playable else Color(0.4, 0.4, 0.4))
	diff_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(diff_label)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var title_label := Label.new()
	title_label.text = case_data.get("title", "未知案件")
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE if playable else Color(0.5, 0.5, 0.5))
	info_vbox.add_child(title_label)

	var sub_label := Label.new()
	sub_label.text = case_data.get("subtitle", "")
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", ThemeManager.COLORS.get("text_secondary", Color(0.6, 0.6, 0.7)))
	info_vbox.add_child(sub_label)

	var tags_text := ""
	for tag in case_data.get("tags", []):
		tags_text += "[%s] " % tag
	if not tags_text.is_empty():
		var tag_label := Label.new()
		tag_label.text = tags_text.strip_edges()
		tag_label.add_theme_font_size_override("font_size", 12)
		tag_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
		info_vbox.add_child(tag_label)

	if playable:
		var play_btn := Button.new()
		play_btn.text = "开始"
		play_btn.custom_minimum_size = Vector2(100, 40)
		ThemeManager.style_button(play_btn)
		var dialogue_path: String = case_data.get("dialogue_path", "")
		play_btn.pressed.connect(_on_case_start.bind(dialogue_path))
		hbox.add_child(play_btn)
	else:
		var lock_label := Label.new()
		lock_label.text = "即将开放"
		lock_label.add_theme_font_size_override("font_size", 14)
		lock_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lock_label)

	parent.add_child(panel)

func _on_case_start(dialogue_path: String) -> void:
	if dialogue_path.is_empty():
		return
	GameManager.next_dialogue_path = dialogue_path
	GameManager.change_state(GameManager.STATE_DAILY_LIFE)
	get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")
