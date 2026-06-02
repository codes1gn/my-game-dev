extends Control

func _ready() -> void:
	_apply_theme()
	AudioManager.play_bgm("menu")
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/QuitButton.pressed.connect(_on_quit)
	if $VBox.has_node("CaseSelectButton"):
		$VBox/CaseSelectButton.pressed.connect(_on_case_select)
	if $VBox.has_node("InvestigateButton"):
		$VBox/InvestigateButton.pressed.connect(_on_investigate)

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

	$VBox/Title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	$VBox/Title.add_theme_font_size_override("font_size", 56)

	$VBox/Subtitle.add_theme_color_override("font_color", ThemeManager.COLORS["text_secondary"])
	$VBox/Subtitle.add_theme_font_size_override("font_size", 18)

	for child in $VBox.get_children():
		if child is Button:
			ThemeManager.style_button(child)
			child.custom_minimum_size = Vector2(320, 52)

	var line := ColorRect.new()
	line.color = ThemeManager.COLORS["accent_gold_dim"]
	line.custom_minimum_size = Vector2(200, 1)
	$VBox.add_child(line)
	$VBox.move_child(line, 2)

func _on_start() -> void:
	GameManager.change_state(GameManager.STATE_DAILY_LIFE)
	get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")

func _on_case_select() -> void:
	get_tree().change_scene_to_file("res://src/ui/case_select.tscn")

func _on_investigate() -> void:
	GameManager.change_state(GameManager.STATE_INVESTIGATION)
	get_tree().change_scene_to_file("res://src/investigation/investigation_scene.tscn")

func _on_quit() -> void:
	get_tree().quit()
