extends Control

@onready var title_label: Label = $TitleBar/TitleLabel
@onready var points_label: Label = $TitleBar/PointsLabel
@onready var item_grid: GridContainer = $Scroll/ItemGrid
@onready var back_button: Button = $BottomBar/BackButton
@onready var inventory_label: Label = $BottomBar/InventoryLabel

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_apply_theme()
	_build_shop()

func _apply_theme() -> void:
	var bg_tex := ThemeManager.generate_gradient_bg(960, 540, Color(0.05, 0.05, 0.09), Color(0.03, 0.03, 0.06))
	$Background.texture = bg_tex
	$Background.expand_mode = 1
	$Background.stretch_mode = 6
	title_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	points_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	inventory_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	ThemeManager.style_button(back_button)

func _build_shop() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	_refresh_points()
	_refresh_inventory()

	var shop_items := GameManager.get_shop_items()
	for item: Dictionary in shop_items:
		var card := _create_item_card(item)
		item_grid.add_child(card)

func _create_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 140)

	var owned := GameManager.has_item(item["id"])
	var can_buy := not owned or item.get("consumable", false)
	var afford := GameManager.player_data.get("system_points", 0) >= item.get("cost", 0)

	var bg_color := Color(0.1, 0.2, 0.1, 0.9) if owned else Color(0.08, 0.08, 0.13, 0.9)
	var border_color := Color(0.3, 0.7, 0.3) if owned else ThemeManager.COLORS["border"]
	var style := ThemeManager.make_panel_style(bg_color, border_color, 6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = item.get("icon", "") + " " + item.get("name", "")
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	vbox.add_child(header)

	var desc := Label.new()
	desc.text = item.get("description", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	vbox.add_child(desc)

	var cost_label := Label.new()
	cost_label.text = "价格: %d 点" % item.get("cost", 0)
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	vbox.add_child(cost_label)

	var buy_btn := Button.new()
	if owned and not item.get("consumable", false):
		buy_btn.text = "✓ 已拥有"
		buy_btn.disabled = true
	elif not afford:
		buy_btn.text = "点数不足"
		buy_btn.disabled = true
	else:
		buy_btn.text = "购买"

	ThemeManager.style_button(buy_btn)
	buy_btn.custom_minimum_size = Vector2(0, 32)

	var item_id: String = item["id"]
	buy_btn.pressed.connect(func():
		if GameManager.buy_item(item_id):
			_build_shop()
	)
	vbox.add_child(buy_btn)

	return card

func _refresh_points() -> void:
	points_label.text = "系统点数: %d" % GameManager.player_data.get("system_points", 0)

func _refresh_inventory() -> void:
	var inv: Array = GameManager.player_data.get("inventory", [])
	if inv.is_empty():
		inventory_label.text = "已拥有: 无"
	else:
		var names: Array[String] = []
		for item_id: String in inv:
			var data := GameManager.get_item_data(item_id)
			if not data.is_empty():
				names.append(data.get("icon", "") + data.get("name", item_id))
		inventory_label.text = "已拥有: " + ", ".join(names)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
