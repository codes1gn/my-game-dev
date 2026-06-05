extends Control

## Talent tree UI — displays 5 skill branches, each with 3 tiers.
## Players spend system_points to unlock talents that boost attributes
## and unlock special investigation skills.

@onready var title_label: Label = $TitleBar/TitleLabel
@onready var points_label: Label = $TitleBar/PointsLabel
@onready var branch_container: HBoxContainer = $Scroll/BranchContainer
@onready var back_button: Button = $BottomBar/BackButton
@onready var confirm_popup: PanelContainer = $ConfirmPopup
@onready var confirm_title: Label = $ConfirmPopup/Margin/VBox/ConfirmTitle
@onready var confirm_desc: RichTextLabel = $ConfirmPopup/Margin/VBox/ConfirmDesc
@onready var confirm_yes: Button = $ConfirmPopup/Margin/VBox/ConfirmButtons/ConfirmYes
@onready var confirm_no: Button = $ConfirmPopup/Margin/VBox/ConfirmButtons/ConfirmNo

const TIER_COLORS := {
	1: Color(0.5, 0.7, 1.0),
	2: Color(0.6, 0.4, 0.9),
	3: Color(1.0, 0.84, 0.0),
}

var _tree_data: Dictionary = {}
var _talent_buttons: Dictionary = {}  # talent_id -> Button
var _pending_talent_id: String = ""

func _ready() -> void:
	confirm_popup.visible = false
	back_button.pressed.connect(_on_back)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(func(): confirm_popup.visible = false)
	_apply_theme()
	_load_tree()

func _apply_theme() -> void:
	var bg_tex := ThemeManager.generate_gradient_bg(960, 540, Color(0.05, 0.05, 0.09), Color(0.03, 0.03, 0.06))
	$Background.texture = bg_tex
	$Background.expand_mode = 1
	$Background.stretch_mode = 6

	title_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	points_label.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])

	ThemeManager.style_button(back_button)

	var popup_style := ThemeManager.make_panel_style(
		Color(0.06, 0.06, 0.09, 0.96),
		ThemeManager.COLORS["accent_gold_dim"], 8
	)
	confirm_popup.add_theme_stylebox_override("panel", popup_style)
	confirm_title.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	ThemeManager.style_button(confirm_yes)
	ThemeManager.style_button(confirm_no)

func _load_tree() -> void:
	_tree_data = GameManager.load_json("res://data/talent_tree.json")
	if _tree_data == null:
		push_error("[TalentTree] Failed to load talent_tree.json")
		return
	_refresh_points()
	_build_branches()

func _refresh_points() -> void:
	var pts: int = GameManager.player_data.get("system_points", 0)
	points_label.text = "系统点数: %d" % pts


# --- Build UI ---

func _build_branches() -> void:
	for child in branch_container.get_children():
		child.queue_free()
	_talent_buttons.clear()

	var branches: Array = _tree_data.get("branches", [])
	for branch: Dictionary in branches:
		var panel := _create_branch_panel(branch)
		branch_container.add_child(panel)

func _create_branch_panel(branch: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 400)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := ThemeManager.make_panel_style(
		Color(0.08, 0.08, 0.13, 0.9),
		ThemeManager.COLORS["border"], 6
	)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = branch.get("icon", "") + " " + branch.get("name", "")
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", ThemeManager.COLORS["accent_gold"])
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var attr_label := Label.new()
	var attr_name: String = branch.get("attribute", "")
	var attr_val: int = GameManager.get_attribute(attr_name)
	attr_label.text = _attr_display_name(attr_name) + ": " + str(attr_val)
	attr_label.add_theme_font_size_override("font_size", 13)
	attr_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(attr_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var talents: Array = branch.get("talents", [])
	for talent: Dictionary in talents:
		var btn := _create_talent_button(talent)
		vbox.add_child(btn)

		if talent.get("tier", 1) < 3:
			var arrow := Label.new()
			arrow.text = "  ↓"
			arrow.add_theme_font_size_override("font_size", 16)
			arrow.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(arrow)

	return panel

func _create_talent_button(talent: Dictionary) -> Button:
	var btn := Button.new()
	var tid: String = talent["id"]
	var tier: int = talent.get("tier", 1)
	var is_gold: bool = talent.get("is_gold", false)
	var cost: int = talent.get("cost", 10)
	var unlocked := GameManager.has_talent(tid)
	var can_unlock := _can_unlock(talent)

	var prefix := "★ " if is_gold else ""
	btn.text = prefix + talent.get("name", "") + "\n(" + str(cost) + " 点)"
	btn.custom_minimum_size = Vector2(150, 50)
	btn.add_theme_font_size_override("font_size", 13)

	if unlocked:
		var s := ThemeManager.make_panel_style(
			Color(0.1, 0.25, 0.1, 0.95),
			TIER_COLORS[tier], 4
		)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_color_override("font_color", TIER_COLORS[tier])
		btn.tooltip_text = "✓ 已学习\n" + talent.get("description", "")
	elif can_unlock:
		ThemeManager.style_button(btn)
		btn.add_theme_color_override("font_color", TIER_COLORS[tier])
		btn.tooltip_text = talent.get("description", "") + "\n消耗: " + str(cost) + " 系统点数"
	else:
		var locked_style := ThemeManager.make_panel_style(
			Color(0.06, 0.06, 0.08, 0.9),
			Color(0.2, 0.2, 0.25), 4
		)
		btn.add_theme_stylebox_override("normal", locked_style)
		btn.add_theme_stylebox_override("hover", locked_style)
		btn.add_theme_stylebox_override("pressed", locked_style)
		btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		var lock_reason := _get_lock_reason(talent)
		btn.tooltip_text = "🔒 " + lock_reason + "\n" + talent.get("description", "")

	btn.pressed.connect(func():
		_on_talent_pressed(tid)
	)
	_talent_buttons[tid] = btn
	return btn


# --- Unlock logic ---

func _can_unlock(talent: Dictionary) -> bool:
	var tid: String = talent["id"]
	if GameManager.has_talent(tid):
		return false
	var cost: int = talent.get("cost", 10)
	if GameManager.player_data.get("system_points", 0) < cost:
		return false
	var reqs: Array = talent.get("requires", [])
	for req: String in reqs:
		if not GameManager.has_talent(req):
			return false
	return true

func _get_lock_reason(talent: Dictionary) -> String:
	var reqs: Array = talent.get("requires", [])
	for req: String in reqs:
		if not GameManager.has_talent(req):
			return "需要先学习前置技能"
	var cost: int = talent.get("cost", 10)
	var pts: int = GameManager.player_data.get("system_points", 0)
	if pts < cost:
		return "点数不足（需要 %d，当前 %d）" % [cost, pts]
	return "已锁定"

func _find_talent(tid: String) -> Dictionary:
	var branches: Array = _tree_data.get("branches", [])
	for branch: Dictionary in branches:
		var talents: Array = branch.get("talents", [])
		for talent: Dictionary in talents:
			if talent["id"] == tid:
				return talent
	return {}

func _on_talent_pressed(tid: String) -> void:
	var talent := _find_talent(tid)
	if talent.is_empty():
		return
	if GameManager.has_talent(tid):
		return
	if not _can_unlock(talent):
		return

	_pending_talent_id = tid
	var is_gold: bool = talent.get("is_gold", false)
	var prefix := "★ " if is_gold else ""
	confirm_title.text = "学习: " + prefix + talent.get("name", "")
	confirm_desc.text = talent.get("description", "") + "\n\n[color=gold]消耗: " + str(talent.get("cost", 0)) + " 系统点数[/color]"
	confirm_popup.visible = true

func _on_confirm_yes() -> void:
	confirm_popup.visible = false
	if _pending_talent_id == "":
		return

	var talent := _find_talent(_pending_talent_id)
	if talent.is_empty() or not _can_unlock(talent):
		_pending_talent_id = ""
		return

	var cost: int = talent.get("cost", 10)
	GameManager.add_system_points(-cost)
	GameManager.unlock_talent(_pending_talent_id)

	var effect: Dictionary = talent.get("effect", {})
	var attr: String = effect.get("attribute", "")
	var boost: int = effect.get("value", 0)
	if attr != "" and boost > 0:
		GameManager.modify_attribute(attr, boost)
	var skill: String = effect.get("skill", "")
	if skill != "":
		GameManager.activate_skill(skill)

	_pending_talent_id = ""
	_refresh_points()
	_build_branches()


# --- Helpers ---

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
