extends Control

@onready var title_label: Label = $TitleBar/TitleLabel
@onready var evidence_list: VBoxContainer = $HSplit/LeftPanel/Scroll/EvidenceList
@onready var question_container: VBoxContainer = $HSplit/RightPanel/Scroll/QuestionContainer
@onready var submit_button: Button = $BottomBar/SubmitButton
@onready var result_popup: PanelContainer = $ResultPopup
@onready var result_title: Label = $ResultPopup/Margin/VBox/ResultTitle
@onready var result_desc: RichTextLabel = $ResultPopup/Margin/VBox/ResultDesc
@onready var result_close: Button = $ResultPopup/Margin/VBox/ResultClose

var _case_data: Dictionary = {}
var _evidence_data: Array[Dictionary] = []
var _answers: Dictionary = {}
var _correct_answers: Dictionary = {}

func _ready() -> void:
	result_popup.visible = false
	submit_button.pressed.connect(_on_submit)
	result_close.pressed.connect(func(): result_popup.visible = false; _return_to_menu())
	_apply_theme()
	_load_case("res://data/cases/case_001_deduction.json")

func _apply_theme() -> void:
	var bg_tex := ThemeManager.generate_gradient_bg(960, 540, Color(0.06, 0.06, 0.10), Color(0.04, 0.04, 0.06))
	$Background.texture = bg_tex
	$Background.expand_mode = 1
	$Background.stretch_mode = 6

	title_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])

	var left_style := ThemeManager.make_panel_style(Color(0.08, 0.08, 0.12, 0.9), ThemeManager.COLORS["border"], 6)
	$HSplit/LeftPanel.add_theme_stylebox_override("panel", left_style)
	var right_style := ThemeManager.make_panel_style(Color(0.08, 0.08, 0.12, 0.9), ThemeManager.COLORS["border"], 6)
	$HSplit/RightPanel.add_theme_stylebox_override("panel", right_style)

	ThemeManager.style_button(submit_button)
	submit_button.add_theme_font_size_override("font_size", 22)

	var popup_style := ThemeManager.make_panel_style(
		Color(0.06, 0.06, 0.09, 0.96),
		ThemeManager.COLORS["accent_gold_dim"], 8
	)
	result_popup.add_theme_stylebox_override("panel", popup_style)
	result_title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	ThemeManager.style_button(result_close)

func _load_case(path: String) -> void:
	_case_data = GameManager.load_json(path)
	if _case_data == null:
		push_error("[Deduction] Failed to load: " + path)
		return

	title_label.text = _case_data.get("title", "推理板")
	_correct_answers = _case_data.get("correct_answers", {})
	_build_evidence_panel()
	_build_questions()

func _build_evidence_panel() -> void:
	for child in evidence_list.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "已收集证据"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	evidence_list.add_child(header)

	var sep := HSeparator.new()
	evidence_list.add_child(sep)

	var evidence_items: Array = _case_data.get("evidence_summary", [])
	for ev in evidence_items:
		var item := Label.new()
		item.text = "\u2022 " + ev.get("name", "") + ": " + ev.get("finding", "")
		item.add_theme_font_size_override("font_size", 14)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.custom_minimum_size = Vector2(300, 0)
		evidence_list.add_child(item)

func _build_questions() -> void:
	for child in question_container.get_children():
		child.queue_free()

	var questions: Array = _case_data.get("questions", [])
	for q in questions:
		var q_label := Label.new()
		q_label.text = q.get("prompt", "")
		q_label.add_theme_font_size_override("font_size", 18)
		q_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
		q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q_label.custom_minimum_size = Vector2(400, 0)
		question_container.add_child(q_label)

		var option_group := VBoxContainer.new()
		option_group.add_theme_constant_override("separation", 4)
		var q_id: String = q["id"]
		var options: Array = q.get("options", [])
		for i in range(options.size()):
			var opt: Dictionary = options[i]
			var btn := Button.new()
			btn.text = opt.get("text", "")
			btn.toggle_mode = true
			btn.add_theme_font_size_override("font_size", 15)
			ThemeManager.style_button(btn)
			var opt_id: String = opt.get("id", str(i))
			btn.pressed.connect(func():
				_answers[q_id] = opt_id
				_highlight_selected(option_group, btn)
			)
			option_group.add_child(btn)

		question_container.add_child(option_group)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		question_container.add_child(spacer)

func _highlight_selected(group: VBoxContainer, selected: Button) -> void:
	for child in group.get_children():
		if child is Button:
			child.button_pressed = (child == selected)

func _on_submit() -> void:
	var questions: Array = _case_data.get("questions", [])
	if _answers.size() < questions.size():
		result_title.text = "尚未完成"
		result_desc.text = "请回答所有问题后再提交推理结论。"
		result_popup.visible = true
		return

	var correct_count := 0
	var total := _correct_answers.size()
	for key: String in _correct_answers:
		if _answers.get(key, "") == _correct_answers[key]:
			correct_count += 1

	var score := int(float(correct_count) / float(total) * 100.0) if total > 0 else 0
	var points_earned := correct_count * 10

	GameManager.add_system_points(points_earned)

	if correct_count == total:
		result_title.text = "完美推理！"
		result_desc.text = "所有推理全部正确！你成功洗清了自己的嫌疑。\n\n获得系统点数: +%d\n当前总点数: %d" % [points_earned, GameManager.player_data["system_points"]]
	elif correct_count > 0:
		result_title.text = "部分正确"
		result_desc.text = "正确: %d / %d\n\n有些推理还需要更多证据支持。\n\n获得系统点数: +%d" % [correct_count, total, points_earned]
	else:
		result_title.text = "推理失败"
		result_desc.text = "推理全部错误。需要重新审视证据。"

	EventBus.deduction_submitted.emit(_case_data.get("case_id", ""), _answers)
	EventBus.case_completed.emit(_case_data.get("case_id", ""), score, points_earned)
	result_popup.visible = true

func _return_to_menu() -> void:
	var conclusion_path := "res://data/dialogue/case_001_conclusion.json"
	if FileAccess.file_exists(conclusion_path):
		GameManager.next_dialogue_path = conclusion_path
		get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
