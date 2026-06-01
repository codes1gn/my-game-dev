extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/QuitButton.pressed.connect(_on_quit)

func _on_start() -> void:
	GameManager.change_state(GameManager.STATE_DAILY_LIFE)
	get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")

func _on_quit() -> void:
	get_tree().quit()
