extends Control

@onready var scene_map: TextureRect = $SceneMap
@onready var hotspot_container: Control = $HotspotContainer
@onready var evidence_popup: PanelContainer = $EvidencePopup
@onready var evidence_title: Label = $EvidencePopup/Margin/VBox/TitleLabel
@onready var evidence_desc: RichTextLabel = $EvidencePopup/Margin/VBox/DescLabel
@onready var evidence_actions: VBoxContainer = $EvidencePopup/Margin/VBox/Actions
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var back_button: Button = $StatusBar/BackButton
@onready var check_banner: PanelContainer = $CheckBanner
@onready var banner_label: Label = $CheckBanner/BannerLabel
@onready var item_bar: HBoxContainer = $ItemBar
@onready var time_bar: PanelContainer = $TimeBar
@onready var time_label: Label = $TimeBar/TimeHBox/TimeLabel
@onready var time_progress: ProgressBar = $TimeBar/TimeHBox/TimeProgress

var _scene_data: Dictionary = {}
var _discovered_evidence: Array[String] = []
var _current_hotspot_id: String = ""
var _banner_timer: SceneTreeTimer = null
var _active_item: String = ""
var _time_budget_enabled := false

func _ready() -> void:
	evidence_popup.visible = false
	back_button.pressed.connect(_on_back)
	_build_item_bar()
	AudioManager.play_bgm("investigation")
	var scene_path: String = GameManager.get_flag("current_scene_path", "res://data/scenes/case_001_apartment.json")
	_load_scene(scene_path)
	_apply_theme()
	_init_time_budget()

func _apply_theme() -> void:
	var bg_path: String = _scene_data.get("background", "")
	var bg_tex: ImageTexture = null
	if not bg_path.is_empty():
		bg_tex = ThemeManager.load_external_image(bg_path)
	if bg_tex == null:
		bg_tex = ThemeManager.load_external_image("res://assets/scenes/bg_apartment.jpg")
	if bg_tex:
		$Background.texture = bg_tex
	else:
		var scene_id: String = _scene_data.get("id", "")
		var scene_type := "apartment"
		for key in ["temple", "mansion", "clinic", "house", "port", "bar"]:
			if key in scene_id:
				scene_type = key
				break
		$Background.texture = ThemeManager.generate_crime_scene_bg(1920, 1080, scene_type)
	$Background.expand_mode = 1
	$Background.stretch_mode = 6

	var map_style := ThemeManager.make_panel_style(Color(0.12, 0.14, 0.18, 0.9), Color(0.25, 0.22, 0.15, 0.4), 4)
	$SceneMapBg.visible = false

	$SceneLabel.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	status_label.add_theme_color_override("font_color", ThemeManager.COLORS["text_primary"])
	ThemeManager.style_button(back_button)

	var popup_style := ThemeManager.make_panel_style(
		Color(0.06, 0.06, 0.09, 0.95),
		ThemeManager.COLORS["accent_gold_dim"], 8
	)
	evidence_popup.add_theme_stylebox_override("panel", popup_style)
	evidence_title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])

func _load_scene(path: String) -> void:
	_scene_data = GameManager.load_json(path)
	if _scene_data == null:
		push_error("[Investigation] Failed to load scene: " + path)
		return

	_build_hotspots()
	_update_status()

func _build_hotspots() -> void:
	for child in hotspot_container.get_children():
		child.queue_free()

	var hotspots: Array = _scene_data.get("hotspots", [])
	for hs in hotspots:
		var btn := Button.new()
		btn.name = hs["id"]
		var time_cost: int = hs.get("time_cost", 30)
		if _time_budget_enabled:
			btn.text = hs.get("label", "?") + " (%dm)" % time_cost
		else:
			btn.text = hs.get("label", "?")
		var rect: Dictionary = hs.get("rect", {})
		btn.position = Vector2(rect.get("x", 0), rect.get("y", 0))
		btn.custom_minimum_size = Vector2(rect.get("w", 80), rect.get("h", 60))
		btn.size = btn.custom_minimum_size
		btn.add_theme_font_size_override("font_size", 16)
		ThemeManager.style_button(btn)
		btn.modulate = Color(1, 1, 1, 0.85)

		var hs_id: String = hs["id"]
		btn.pressed.connect(func(): _on_hotspot_clicked(hs_id))
		hotspot_container.add_child(btn)

func _on_hotspot_clicked(hotspot_id: String) -> void:
	if _time_budget_enabled and GameManager.is_time_up():
		return

	_current_hotspot_id = hotspot_id
	var hotspot: Dictionary = _get_hotspot(hotspot_id)
	if hotspot.is_empty():
		return

	_spend_time_for_hotspot(hotspot)
	if _time_budget_enabled and GameManager.is_time_up():
		return

	var evidence_ids: Array = hotspot.get("evidence_ids", [])
	var interaction: String = hotspot.get("interaction", "examine")

	match interaction:
		"examine":
			if evidence_ids.is_empty():
				_show_simple_popup(hotspot.get("label", ""), "这里没有发现有价值的线索。")
			else:
				_show_evidence(evidence_ids[0])
		"surveillance":
			if not evidence_ids.is_empty():
				_show_evidence(evidence_ids[0])
			else:
				_show_simple_popup("监控录像", "正在回放监控画面...\n[监控布局尚未实现 — 原型占位]")

func _show_evidence(evidence_id: String) -> void:
	var case_id: String = _scene_data.get("id", "case_001")
	var ev_path := "res://data/evidence/%s/%s.json" % [case_id, evidence_id]
	var ev_data: Variant = GameManager.load_json(ev_path)
	if ev_data == null:
		_show_simple_popup("证据", "发现了一些线索... [数据文件缺失: %s]" % evidence_id)
		if evidence_id not in _discovered_evidence:
			_discovered_evidence.append(evidence_id)
			EventBus.evidence_discovered.emit(evidence_id)
			_update_status()
		return

	evidence_title.text = ev_data.get("name", "未知证据")
	var desc: String = ev_data.get("description", "")
	evidence_desc.bbcode_enabled = true
	evidence_desc.text = desc

	for child in evidence_actions.get_children():
		child.queue_free()

	var analyses: Array = ev_data.get("analysis_options", [])
	for analysis in analyses:
		var action_btn := Button.new()
		var skill_req: Variant = analysis.get("skill_required", null)
		var action_label: String = analysis.get("action", "检查")
		var result_text: String = analysis.get("result", "无结果")

		if skill_req != null and skill_req is Dictionary:
			var attr_name: String = (skill_req as Dictionary).keys()[0]
			var threshold: int = (skill_req as Dictionary).values()[0]
			var display_attr := _attr_display_name(attr_name)
			action_btn.text = action_label + "  [%s %d]" % [display_attr, threshold]
			ThemeManager.style_button(action_btn)

			action_btn.pressed.connect(func():
				if _is_item_auto_pass():
					evidence_desc.text = desc + "\n\n【分析结果】(道具辅助)\n" + result_text
					_show_check_success(display_attr + "(道具)", {"success_rate": 100})
					return
				var bonus := _get_item_check_bonus(attr_name)
				var effective_threshold := maxi(1, threshold - bonus)
				var check := GameManager.soft_check(attr_name, effective_threshold)
				if bonus > 0:
					check["item_bonus"] = bonus
				if check["passed"]:
					var extra := ""
					if bonus > 0:
						extra = " (道具加成 +%d)" % bonus
					evidence_desc.text = desc + "\n\n【分析结果】" + extra + "\n" + result_text
					_show_check_success(display_attr, check)
				else:
					evidence_desc.text = desc + "\n\n[i]你的%s不足以进行这项分析...[/i]" % display_attr
					_show_check_fail(display_attr, check)
			)
		else:
			action_btn.text = action_label
			ThemeManager.style_button(action_btn)
			action_btn.pressed.connect(func():
				evidence_desc.text = desc + "\n\n【分析结果】\n" + result_text
			)

		evidence_actions.add_child(action_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	ThemeManager.style_button(close_btn)
	close_btn.pressed.connect(func(): evidence_popup.visible = false)
	evidence_actions.add_child(close_btn)

	evidence_popup.visible = true

	if evidence_id not in _discovered_evidence:
		_discovered_evidence.append(evidence_id)
		EventBus.evidence_discovered.emit(evidence_id)
		_update_status()

func _show_simple_popup(title: String, desc: String) -> void:
	evidence_title.text = title
	evidence_desc.text = desc

	for child in evidence_actions.get_children():
		child.queue_free()

	var close_btn := Button.new()
	close_btn.text = "关闭"
	ThemeManager.style_button(close_btn)
	close_btn.pressed.connect(func(): evidence_popup.visible = false)
	evidence_actions.add_child(close_btn)

	evidence_popup.visible = true

func _get_hotspot(id: String) -> Dictionary:
	for hs in _scene_data.get("hotspots", []):
		if hs["id"] == id:
			return hs
	return {}

func _update_status() -> void:
	var total_evidence := 0
	for hs in _scene_data.get("hotspots", []):
		total_evidence += (hs.get("evidence_ids", []) as Array).size()
	status_label.text = "已发现证据: %d / %d" % [_discovered_evidence.size(), total_evidence]
	if _discovered_evidence.size() >= total_evidence and total_evidence > 0:
		_show_all_found()

func _show_all_found() -> void:
	status_label.text = "所有证据已收集！"
	var deduce_btn := Button.new()
	deduce_btn.text = "开始推理"
	deduce_btn.add_theme_font_size_override("font_size", 18)
	deduce_btn.custom_minimum_size = Vector2(140, 40)
	ThemeManager.style_button(deduce_btn)
	deduce_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/investigation/deduction_board.tscn")
	)
	$StatusBar.add_child(deduce_btn)
	$StatusBar.move_child(deduce_btn, 1)

func _init_time_budget() -> void:
	_time_budget_enabled = _scene_data.get("time_budget_enabled", false)
	if _time_budget_enabled:
		GameManager.start_time_budget()
		time_bar.visible = true
		_refresh_time_display()
		var time_style := ThemeManager.make_panel_style(
			Color(0.06, 0.06, 0.10, 0.9),
			ThemeManager.COLORS["border"], 4
		)
		time_bar.add_theme_stylebox_override("panel", time_style)
	else:
		time_bar.visible = false

func _refresh_time_display() -> void:
	time_label.text = "剩余: " + GameManager.get_time_display()
	time_progress.max_value = GameManager.BASE_TIME_BUDGET + GameManager.get_attribute("fitness") * 10
	time_progress.value = GameManager.time_remaining

	var pct := float(GameManager.time_remaining) / float(time_progress.max_value)
	if pct <= 0.2:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif pct <= 0.5:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		time_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))

func _spend_time_for_hotspot(hotspot: Dictionary) -> void:
	if not _time_budget_enabled:
		return
	var cost: int = hotspot.get("time_cost", 30)
	GameManager.spend_time(cost)
	_refresh_time_display()

	if GameManager.is_time_up():
		_on_time_up()

func _on_time_up() -> void:
	evidence_popup.visible = false
	_show_check_fail("时间", {"success_rate": 0})
	banner_label.text = "【时间耗尽！】强制进入推理阶段"

	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		get_tree().change_scene_to_file("res://src/investigation/deduction_board.tscn")
	, CONNECT_ONE_SHOT)

func _build_item_bar() -> void:
	for child in item_bar.get_children():
		if child.name != "ItemBarLabel":
			child.queue_free()

	var inventory: Array = GameManager.player_data.get("inventory", [])
	if inventory.is_empty():
		return

	var seen: Dictionary = {}
	for item_id: String in inventory:
		if item_id in seen:
			continue
		seen[item_id] = true
		var data := GameManager.get_item_data(item_id)
		if data.is_empty():
			continue
		var btn := Button.new()
		btn.text = data.get("icon", "?")
		btn.tooltip_text = data.get("name", item_id) + "\n" + data.get("description", "")
		btn.custom_minimum_size = Vector2(36, 36)
		btn.toggle_mode = true
		ThemeManager.style_button(btn)
		btn.add_theme_font_size_override("font_size", 18)

		var iid: String = item_id
		btn.toggled.connect(func(pressed: bool):
			if pressed:
				_active_item = iid
				_deselect_other_items(btn)
			else:
				_active_item = ""
		)
		item_bar.add_child(btn)

func _deselect_other_items(keep: Button) -> void:
	for child in item_bar.get_children():
		if child is Button and child != keep:
			child.button_pressed = false

func _get_item_check_bonus(attr_name: String) -> int:
	if _active_item == "":
		return 0
	var data := GameManager.get_item_data(_active_item)
	if data.is_empty():
		return 0
	var effect: Dictionary = data.get("effect", {})
	if effect.get("type", "") == "attribute_bonus" and effect.get("attribute", "") == attr_name:
		return effect.get("bonus", 0)
	return 0

func _is_item_auto_pass() -> bool:
	if _active_item == "":
		return false
	var data := GameManager.get_item_data(_active_item)
	return data.get("investigation_effect", "") == "auto_pass_check"

func _show_check_success(attr_display: String, check: Dictionary) -> void:
	var rate: int = check.get("success_rate", 50)
	banner_label.text = "【%s检定成功！】 (成功率 %d%%)" % [attr_display, rate]
	var style := ThemeManager.make_panel_style(
		Color(0.05, 0.2, 0.05, 0.95),
		Color(1.0, 0.84, 0.0, 0.8), 4
	)
	check_banner.add_theme_stylebox_override("panel", style)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_flash_banner()

func _show_check_fail(attr_display: String, check: Dictionary) -> void:
	var rate: int = check.get("success_rate", 50)
	banner_label.text = "【%s检定失败】 (成功率 %d%%)" % [attr_display, rate]
	var style := ThemeManager.make_panel_style(
		Color(0.2, 0.05, 0.05, 0.95),
		Color(0.6, 0.2, 0.2, 0.8), 4
	)
	check_banner.add_theme_stylebox_override("panel", style)
	banner_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_flash_banner()

func _flash_banner() -> void:
	check_banner.visible = true
	check_banner.modulate = Color(1, 1, 1, 1)
	if _banner_timer != null and _banner_timer.time_left > 0:
		pass
	_banner_timer = get_tree().create_timer(2.5)
	_banner_timer.timeout.connect(func():
		var tween := create_tween()
		tween.tween_property(check_banner, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(func(): check_banner.visible = false)
	, CONNECT_ONE_SHOT)

func _attr_display_name(attr: String) -> String:
	match attr:
		"observation": return "观察力"
		"interrogation": return "审讯力"
		"forensics": return "鉴定学"
		"psychology": return "心理学"
		"fitness": return "体能"
		"charisma": return "魅力"
		_: return attr

func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
