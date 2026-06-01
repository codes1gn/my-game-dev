extends VBoxContainer

signal choice_selected(index: int)

var _buttons: Array[Button] = []

func show_choices(options: Array) -> void:
	_clear()
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = opt.get("text", "???")
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 20)
		ThemeManager.style_button(btn)
		var idx := i
		btn.pressed.connect(func(): _on_choice(idx))
		add_child(btn)
		_buttons.append(btn)
	visible = true

func _on_choice(index: int) -> void:
	choice_selected.emit(index)
	_clear()
	visible = false

func _clear() -> void:
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()
