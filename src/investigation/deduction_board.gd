extends Control

## Evidence-linking deduction board.
## Players drag lines between evidence cards to build reasoning chains.
## The engine scores links against the case's correct_links / bonus_links.

@onready var title_label: Label = $TitleBar/TitleLabel
@onready var hint_label: Label = $TitleBar/HintLabel
@onready var canvas: Control = $Canvas
@onready var link_lines: Node2D = $Canvas/LinkLines
@onready var card_container: Control = $Canvas/CardContainer
@onready var submit_button: Button = $BottomBar/SubmitButton
@onready var clear_button: Button = $BottomBar/ClearButton
@onready var link_count_label: Label = $BottomBar/LinkCount
@onready var result_popup: PanelContainer = $ResultPopup
@onready var result_title: Label = $ResultPopup/Margin/VBox/ResultTitle
@onready var result_desc: RichTextLabel = $ResultPopup/Margin/VBox/ResultDesc
@onready var result_close: Button = $ResultPopup/Margin/VBox/ResultClose
@onready var detail_popup: PanelContainer = $DetailPopup
@onready var detail_title: Label = $DetailPopup/Margin/VBox/DetailTitle
@onready var detail_text: RichTextLabel = $DetailPopup/Margin/VBox/DetailText
@onready var detail_close: Button = $DetailPopup/Margin/VBox/DetailClose

const CARD_SIZE := Vector2(140, 80)
const LINK_COLOR := Color(0.5, 0.6, 0.8, 0.8)
const LINK_CORRECT_COLOR := Color(1.0, 0.84, 0.0, 0.9)
const LINK_WRONG_COLOR := Color(0.8, 0.2, 0.2, 0.7)
const LINK_BONUS_COLOR := Color(0.3, 1.0, 0.5, 0.9)
const LINK_WIDTH := 3.0

var _case_data: Dictionary = {}
var _evidence_nodes: Array[Dictionary] = []
var _correct_links: Array[Dictionary] = []
var _bonus_links: Array[Dictionary] = []
var _scoring: Dictionary = {}

var _cards: Dictionary = {}  # id -> PanelContainer
var _player_links: Array[Array] = []  # [[from_id, to_id], ...]

var _dragging_from: String = ""
var _drag_mouse_pos := Vector2.ZERO
var _is_drawing_line := false
var _submitted := false

func _ready() -> void:
	result_popup.visible = false
	detail_popup.visible = false
	submit_button.pressed.connect(_on_submit)
	clear_button.pressed.connect(_on_clear)
	result_close.pressed.connect(func(): result_popup.visible = false; _return_to_menu())
	detail_close.pressed.connect(func(): detail_popup.visible = false)
	link_lines.draw.connect(_draw_links)
	_apply_theme()
	AudioManager.play_bgm("deduction")
	var deduction_path: String = GameManager.get_flag("current_deduction_path", "res://data/cases/case_001_deduction.json")
	_load_case(deduction_path)

func _apply_theme() -> void:
	var bg_tex := ThemeManager.generate_gradient_bg(960, 540, Color(0.06, 0.06, 0.10), Color(0.04, 0.04, 0.06))
	$Background.texture = bg_tex
	$Background.expand_mode = 1
	$Background.stretch_mode = 6

	title_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

	ThemeManager.style_button(submit_button)
	submit_button.add_theme_font_size_override("font_size", 22)
	ThemeManager.style_button(clear_button)

	link_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

	var popup_style := ThemeManager.make_panel_style(
		Color(0.06, 0.06, 0.09, 0.96),
		ThemeManager.COLORS["accent_gold_dim"], 8
	)
	result_popup.add_theme_stylebox_override("panel", popup_style)
	result_title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	ThemeManager.style_button(result_close)

	var detail_style := ThemeManager.make_panel_style(
		Color(0.07, 0.07, 0.11, 0.95),
		ThemeManager.COLORS["border"], 6
	)
	detail_popup.add_theme_stylebox_override("panel", detail_style)
	detail_title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	ThemeManager.style_button(detail_close)


# --- Data loading ---

func _load_case(path: String) -> void:
	_case_data = GameManager.load_json(path)
	if _case_data == null:
		push_error("[Deduction] Failed to load: " + path)
		return

	title_label.text = _case_data.get("title", "推理板")

	var ev_raw: Array = _case_data.get("evidence_nodes", [])
	_evidence_nodes.clear()
	for e in ev_raw:
		_evidence_nodes.append(e as Dictionary)

	var cl_raw: Array = _case_data.get("correct_links", [])
	_correct_links.clear()
	for c in cl_raw:
		_correct_links.append(c as Dictionary)

	var bl_raw: Array = _case_data.get("bonus_links", [])
	_bonus_links.clear()
	for b in bl_raw:
		_bonus_links.append(b as Dictionary)

	_scoring = _case_data.get("scoring", {
		"points_per_correct": 15,
		"bonus_per_extra": 5,
		"penalty_per_wrong": -3,
		"perfect_bonus": 20
	})

	_build_cards()


# --- Card creation ---

func _build_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	_cards.clear()

	var canvas_size := canvas.size
	var positions := _compute_card_positions(canvas_size, _evidence_nodes.size())

	for i in range(_evidence_nodes.size()):
		var ev: Dictionary = _evidence_nodes[i]
		var card := _create_evidence_card(ev)
		card.position = positions[i]
		card_container.add_child(card)
		_cards[ev["id"]] = card

func _compute_card_positions(area: Vector2, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var usable := area - CARD_SIZE - Vector2(20, 20)
	var cx := usable.x / 2.0
	var cy := usable.y / 2.0
	var radius_x := usable.x * 0.38
	var radius_y := usable.y * 0.36

	for i in range(count):
		var angle := (TAU / count) * i - PI / 2.0
		var px := cx + cos(angle) * radius_x
		var py := cy + sin(angle) * radius_y
		positions.append(Vector2(px, py))
	return positions

func _create_evidence_card(ev: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := ThemeManager.make_panel_style(
		Color(0.10, 0.10, 0.16, 0.95),
		ThemeManager.COLORS["border"], 6
	)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = ev.get("label", "证据")
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	var icon_label := Label.new()
	icon_label.text = _icon_for(ev.get("icon", "evidence"))
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	var ev_id: String = ev["id"]

	card.gui_input.connect(func(event: InputEvent):
		_on_card_input(ev_id, event)
	)

	card.mouse_entered.connect(func():
		if not _submitted:
			var hover_style := ThemeManager.make_panel_style(
				Color(0.14, 0.14, 0.22, 0.95),
				ThemeManager.COLORS["accent_gold_dim"], 6
			)
			card.add_theme_stylebox_override("panel", hover_style)
	)
	card.mouse_exited.connect(func():
		if not _submitted:
			card.add_theme_stylebox_override("panel", style)
	)

	return card

func _icon_for(icon_name: String) -> String:
	match icon_name:
		"footprint": return "👣"
		"knife": return "🔪"
		"body": return "🩺"
		"camera": return "📷"
		"document": return "📄"
		_: return "🔍"


# --- Card interaction (drag-to-link) ---

func _on_card_input(card_id: String, event: InputEvent) -> void:
	if _submitted:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_from = card_id
				_is_drawing_line = true
				_drag_mouse_pos = canvas.get_local_mouse_position()
			else:
				if _is_drawing_line and _dragging_from != "":
					var target := _find_card_at(canvas.get_local_mouse_position())
					if target != "" and target != _dragging_from:
						_try_add_link(_dragging_from, target)
					_dragging_from = ""
					_is_drawing_line = false
					link_lines.queue_redraw()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_detail(card_id)

func _input(event: InputEvent) -> void:
	if _is_drawing_line and event is InputEventMouseMotion:
		_drag_mouse_pos = canvas.get_local_mouse_position()
		link_lines.queue_redraw()

	if _is_drawing_line and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			var target := _find_card_at(canvas.get_local_mouse_position())
			if target != "" and target != _dragging_from and _dragging_from != "":
				_try_add_link(_dragging_from, target)
			_dragging_from = ""
			_is_drawing_line = false
			link_lines.queue_redraw()

func _find_card_at(pos: Vector2) -> String:
	for ev_id: String in _cards:
		var card: PanelContainer = _cards[ev_id]
		var rect := Rect2(card.position, card.size)
		if rect.has_point(pos):
			return ev_id
	return ""

func _get_card_center(card_id: String) -> Vector2:
	var card: PanelContainer = _cards[card_id]
	return card.position + card.size / 2.0


# --- Link management ---

func _try_add_link(from_id: String, to_id: String) -> void:
	var key := _sorted_link(from_id, to_id)
	for link: Array in _player_links:
		if _sorted_link(link[0], link[1]) == key:
			_player_links.erase(link)
			_update_link_count()
			link_lines.queue_redraw()
			return

	_player_links.append([from_id, to_id])
	_update_link_count()
	link_lines.queue_redraw()

func _sorted_link(a: String, b: String) -> Array:
	if a < b:
		return [a, b]
	return [b, a]

func _update_link_count() -> void:
	link_count_label.text = "已连接: %d" % _player_links.size()

func _on_clear() -> void:
	if _submitted:
		return
	_player_links.clear()
	_update_link_count()
	link_lines.queue_redraw()


# --- Drawing ---

func _process(_delta: float) -> void:
	if _is_drawing_line and link_lines.is_inside_tree():
		link_lines.queue_redraw()

func _draw_links() -> void:
	for link: Array in _player_links:
		var from_pos := _get_card_center(link[0])
		var to_pos := _get_card_center(link[1])
		var color := LINK_COLOR
		if _submitted:
			color = _get_link_result_color(link[0], link[1])
		link_lines.draw_line(from_pos, to_pos, color, LINK_WIDTH, true)

		var mid := (from_pos + to_pos) / 2.0
		link_lines.draw_circle(mid, 4.0, color)

	if _is_drawing_line and _dragging_from != "":
		var from_pos := _get_card_center(_dragging_from)
		link_lines.draw_line(from_pos, _drag_mouse_pos, Color(1, 1, 1, 0.4), 2.0, true)

func _get_link_result_color(from: String, to: String) -> Color:
	var key := _sorted_link(from, to)
	for cl: Dictionary in _correct_links:
		var ck := _sorted_link(cl["from"], cl["to"])
		if ck == key:
			return LINK_CORRECT_COLOR
	for bl: Dictionary in _bonus_links:
		var bk := _sorted_link(bl["from"], bl["to"])
		if bk == key:
			return LINK_BONUS_COLOR
	return LINK_WRONG_COLOR


# --- Detail popup ---

func _show_detail(card_id: String) -> void:
	for ev: Dictionary in _evidence_nodes:
		if ev["id"] == card_id:
			detail_title.text = ev.get("label", "")
			detail_text.text = ev.get("detail", "")
			detail_popup.visible = true
			return


# --- Submission & scoring ---

func _on_submit() -> void:
	if _submitted:
		return
	if _player_links.size() == 0:
		result_title.text = "尚未连线"
		result_desc.text = "请在证据卡片之间拖拽连线，构建你的推理链后再提交。"
		result_popup.visible = true
		return

	_submitted = true
	var score_data := _evaluate()
	_show_result(score_data)
	link_lines.queue_redraw()

func _evaluate() -> Dictionary:
	var correct_hit := 0
	var bonus_hit := 0
	var wrong_count := 0
	var matched_conclusions: Array[String] = []
	var bonus_conclusions: Array[String] = []

	for link: Array in _player_links:
		var key := _sorted_link(link[0], link[1])
		var found := false

		for cl: Dictionary in _correct_links:
			var ck := _sorted_link(cl["from"], cl["to"])
			if ck == key:
				correct_hit += 1
				matched_conclusions.append(cl.get("tag", "") + ": " + cl.get("conclusion", ""))
				found = true
				break

		if not found:
			for bl: Dictionary in _bonus_links:
				var bk := _sorted_link(bl["from"], bl["to"])
				if bk == key:
					bonus_hit += 1
					bonus_conclusions.append(bl.get("tag", "") + ": " + bl.get("conclusion", ""))
					found = true
					break

		if not found:
			wrong_count += 1

	var pts_correct := correct_hit * _scoring.get("points_per_correct", 15)
	var pts_bonus := bonus_hit * _scoring.get("bonus_per_extra", 5)
	var pts_penalty := wrong_count * abs(_scoring.get("penalty_per_wrong", 3))
	var is_perfect := correct_hit == _correct_links.size() and wrong_count == 0
	var pts_perfect := _scoring.get("perfect_bonus", 20) if is_perfect else 0
	var total := maxi(0, pts_correct + pts_bonus - pts_penalty + pts_perfect)

	return {
		"correct_hit": correct_hit,
		"correct_total": _correct_links.size(),
		"bonus_hit": bonus_hit,
		"wrong_count": wrong_count,
		"total_points": total,
		"is_perfect": is_perfect,
		"matched": matched_conclusions,
		"bonus": bonus_conclusions,
	}

func _show_result(data: Dictionary) -> void:
	var total_points: int = data["total_points"]
	GameManager.add_system_points(total_points)

	var pct := int(float(data["correct_hit"]) / float(data["correct_total"]) * 100.0) if data["correct_total"] > 0 else 0
	var lines: Array[String] = []

	if data["is_perfect"]:
		result_title.text = "完美推理！"
		lines.append("所有关键推理链全部命中！\n")
	elif data["correct_hit"] > 0:
		result_title.text = "部分正确"
		lines.append("命中 %d / %d 条关键推理链 (%d%%)\n" % [data["correct_hit"], data["correct_total"], pct])
	else:
		result_title.text = "推理失败"
		lines.append("未命中任何关键推理链。需要重新审视证据之间的联系。\n")

	if data["matched"].size() > 0:
		lines.append("[color=gold]正确推理：[/color]")
		for m: String in data["matched"]:
			lines.append("  ✓ " + m)
		lines.append("")

	if data["bonus"].size() > 0:
		lines.append("[color=green]额外发现：[/color]")
		for b: String in data["bonus"]:
			lines.append("  ★ " + b)
		lines.append("")

	if data["wrong_count"] > 0:
		lines.append("[color=red]错误连线: %d 条 (扣分 -%d)[/color]" % [data["wrong_count"], data["wrong_count"] * abs(_scoring.get("penalty_per_wrong", 3))])
		lines.append("")

	lines.append("获得系统点数: +%d" % total_points)
	lines.append("当前总点数: %d" % GameManager.player_data["system_points"])

	result_desc.bbcode_enabled = true
	result_desc.text = "\n".join(lines)

	var score := pct
	EventBus.deduction_submitted.emit(_case_data.get("case_id", ""), {})
	EventBus.case_completed.emit(_case_data.get("case_id", ""), score, total_points)
	result_popup.visible = true

func _return_to_menu() -> void:
	var case_id: String = _case_data.get("case_id", "case_001")
	var conclusion_path := "res://data/dialogue/%s_conclusion.json" % case_id
	if FileAccess.file_exists(conclusion_path):
		GameManager.next_dialogue_path = conclusion_path
		get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
