extends Control

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	print("Start button pressed — game logic goes here")

func _on_quit_pressed() -> void:
	get_tree().quit()
