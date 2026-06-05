extends Control

## Save/Load screen with 3 slots. Each slot shows summary info and
## offers Save / Load / Delete actions.

@onready var title_label: Label = $TitleLabel
@onready var slot_container: VBoxContainer = $SlotContainer
@onready var back_button: Button = $BottomBar/BackButton

var _mode: String = "save"  # "save" or "load" — set before _ready via set_mode()

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_mode = GameManager.get_flag("save_load_mode", "save") as String
	_apply_theme()
	_build_slots()

func _apply_theme() -> void:
	var bg_tex := ThemeManager.generate_gradient_bg(960, 540, Color(0.05, 0.05, 0.09), Color(0.03, 0.03, 0.06))
	$Background.texture = bg_tex
	$Background.expand_mode = 1
	$Background.stretch_mode = 6
	title_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	ThemeManager.style_button(back_button)

func _build_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	title_label.text = "存档" if _mode == "save" else "读档"

	for i in range(GameManager.MAX_SLOTS):
		var slot_panel := _create_slot(i)
		slot_container.add_child(slot_panel)

func _create_slot(slot_idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 70)

	var info := GameManager.get_save_info(slot_idx)
	var has_data := not info.is_empty()

	var bg_color := Color(0.08, 0.12, 0.08, 0.9) if has_data else Color(0.08, 0.08, 0.12, 0.9)
	var border := ThemeManager.COLORS["accent_gold_dim"] if has_data else ThemeManager.COLORS["border"]
	var style := ThemeManager.make_panel_style(bg_color, border, 6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var slot_label := Label.new()
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	info_vbox.add_child(slot_label)

	var detail_label := Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	info_vbox.add_child(detail_label)

	if has_data:
		slot_label.text = "槽位 %d — 第 %d 天" % [slot_idx + 1, info.get("day", 1)]
		detail_label.text = "点数:%d  天赋:%d  道具:%d  案件:%d  [%s]" % [
			info.get("points", 0),
			info.get("talents", 0),
			info.get("items", 0),
			info.get("cases_solved", 0),
			info.get("timestamp", ""),
		]
	else:
		slot_label.text = "槽位 %d — 空" % (slot_idx + 1)
		detail_label.text = "无存档"

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	hbox.add_child(actions)

	if _mode == "save":
		var save_btn := Button.new()
		save_btn.text = "覆盖保存" if has_data else "保存"
		save_btn.custom_minimum_size = Vector2(80, 34)
		ThemeManager.style_button(save_btn)
		save_btn.pressed.connect(func():
			GameManager.save_game(slot_idx)
			_build_slots()
		)
		actions.add_child(save_btn)
	else:
		if has_data:
			var load_btn := Button.new()
			load_btn.text = "读取"
			load_btn.custom_minimum_size = Vector2(80, 34)
			ThemeManager.style_button(load_btn)
			load_btn.pressed.connect(func():
				GameManager.load_game(slot_idx)
				get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
			)
			actions.add_child(load_btn)

	if has_data:
		var del_btn := Button.new()
		del_btn.text = "删除"
		del_btn.custom_minimum_size = Vector2(60, 34)
		ThemeManager.style_button(del_btn)
		del_btn.pressed.connect(func():
			GameManager.delete_save(slot_idx)
			_build_slots()
		)
		actions.add_child(del_btn)

	return panel

func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
