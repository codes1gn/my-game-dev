extends Control

func _ready() -> void:
	_apply_theme()
	AudioManager.play_bgm("menu")
	var vbox := $Scroll/VBox
	vbox.get_node("StartButton").pressed.connect(_on_start)
	vbox.get_node("QuitButton").pressed.connect(_on_quit)
	if vbox.has_node("CaseSelectButton"):
		vbox.get_node("CaseSelectButton").pressed.connect(_on_case_select)
	if vbox.has_node("InvestigateButton"):
		vbox.get_node("InvestigateButton").pressed.connect(_on_investigate)
	if vbox.has_node("TalentTreeButton"):
		vbox.get_node("TalentTreeButton").pressed.connect(_on_talent_tree)
	if vbox.has_node("ShopButton"):
		vbox.get_node("ShopButton").pressed.connect(_on_shop)
	if vbox.has_node("SaveButton"):
		vbox.get_node("SaveButton").pressed.connect(_on_save)
	if vbox.has_node("LoadButton"):
		vbox.get_node("LoadButton").pressed.connect(_on_load)

func _apply_theme() -> void:
	var bg_tex := ThemeManager.load_external_image("res://assets/scenes/bg_main_menu.jpg")
	if bg_tex:
		$Background.texture = bg_tex
	else:
		$Background.texture = ThemeManager.generate_vignette_bg(1280, 720, Color(0.05, 0.05, 0.08))
	$Background.expand_mode = 1
	$Background.stretch_mode = 6
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	move_child(overlay, 1)

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox2 := $Scroll/VBox
	vbox2.get_node("Title").add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	vbox2.get_node("Title").add_theme_font_size_override("font_size", 48)

	vbox2.get_node("Subtitle").add_theme_color_override("font_color", ThemeManager.COLORS["text_secondary"])
	vbox2.get_node("Subtitle").add_theme_font_size_override("font_size", 16)

	for child in vbox2.get_children():
		if child is Button:
			ThemeManager.style_button(child)
			child.custom_minimum_size = Vector2(320, 46)

	var line := ColorRect.new()
	line.color = ThemeManager.COLORS["accent_gold_dim"]
	line.custom_minimum_size = Vector2(200, 1)
	vbox2.add_child(line)
	vbox2.move_child(line, 2)

func _on_start() -> void:
	GameManager.change_state(GameManager.STATE_DAILY_LIFE)
	get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")

func _on_case_select() -> void:
	get_tree().change_scene_to_file("res://src/ui/case_select.tscn")

func _on_investigate() -> void:
	GameManager.change_state(GameManager.STATE_INVESTIGATION)
	get_tree().change_scene_to_file("res://src/investigation/investigation_scene.tscn")

func _on_talent_tree() -> void:
	get_tree().change_scene_to_file("res://src/ui/talent_tree.tscn")

func _on_shop() -> void:
	get_tree().change_scene_to_file("res://src/ui/item_shop.tscn")

func _on_save() -> void:
	GameManager.set_flag("save_load_mode", "save")
	get_tree().change_scene_to_file("res://src/ui/save_load.tscn")

func _on_load() -> void:
	GameManager.set_flag("save_load_mode", "load")
	get_tree().change_scene_to_file("res://src/ui/save_load.tscn")

func _on_quit() -> void:
	get_tree().quit()
