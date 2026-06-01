extends PanelContainer

signal text_finished
signal advance_requested

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var continue_indicator: Control = %ContinueIndicator

var _full_text: String = ""
var _char_index: int = 0
var _is_typing: bool = false
var _chars_per_second: float = 40.0

func _ready() -> void:
	continue_indicator.visible = false

func _process(delta: float) -> void:
	if not _is_typing:
		return
	_char_index += delta * _chars_per_second
	var visible_count := int(_char_index)
	if visible_count >= _full_text.length():
		text_label.text = _full_text
		_is_typing = false
		continue_indicator.visible = true
		text_finished.emit()
	else:
		text_label.text = _full_text.substr(0, visible_count)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if _is_typing:
			_skip_typing()
		elif continue_indicator.visible:
			continue_indicator.visible = false
			advance_requested.emit()

func show_dialogue(speaker: String, text: String) -> void:
	if speaker.is_empty() or speaker == "narrator":
		speaker_label.text = ""
	else:
		speaker_label.text = speaker
	_full_text = text
	_char_index = 0.0
	_is_typing = true
	text_label.text = ""
	continue_indicator.visible = false
	visible = true

func _skip_typing() -> void:
	text_label.text = _full_text
	_is_typing = false
	_char_index = float(_full_text.length())
	continue_indicator.visible = true
	text_finished.emit()

func hide_box() -> void:
	visible = false
