extends Control

@onready var scene_map: TextureRect = $SceneMap
@onready var hotspot_container: Control = $HotspotContainer
@onready var evidence_popup: PanelContainer = $EvidencePopup
@onready var evidence_title: Label = $EvidencePopup/Margin/VBox/TitleLabel
@onready var evidence_desc: RichTextLabel = $EvidencePopup/Margin/VBox/DescLabel
@onready var evidence_actions: VBoxContainer = $EvidencePopup/Margin/VBox/Actions
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var back_button: Button = $StatusBar/BackButton

var _scene_data: Dictionary = {}
var _discovered_evidence: Array[String] = []
var _current_hotspot_id: String = ""

func _ready() -> void:
	evidence_popup.visible = false
	back_button.pressed.connect(_on_back)
	_apply_theme()
	_load_scene("res://data/scenes/case_001_apartment.json")

func _apply_theme() -> void:
	var bg_tex := ThemeManager.load_external_image("res://assets/scenes/bg_apartment.jpg")
	if bg_tex:
		$Background.texture = bg_tex
	else:
		$Background.texture = ThemeManager.generate_crime_scene_bg(960, 540)
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
	_current_hotspot_id = hotspot_id
	var hotspot: Dictionary = _get_hotspot(hotspot_id)
	if hotspot.is_empty():
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
	var ev_path := "res://data/evidence/case_001/%s.json" % evidence_id
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
	evidence_desc.text = desc

	for child in evidence_actions.get_children():
		child.queue_free()

	var analyses: Array = ev_data.get("analysis_options", [])
	for analysis in analyses:
		var action_btn := Button.new()
		action_btn.text = analysis.get("action", "检查")
		ThemeManager.style_button(action_btn)
		var result_text: String = analysis.get("result", "无结果")
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

func _on_back() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
