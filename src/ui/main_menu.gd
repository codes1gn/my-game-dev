extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/QuitButton.pressed.connect(_on_quit)
	if $VBox.has_node("InvestigateButton"):
		$VBox/InvestigateButton.pressed.connect(_on_investigate)

func _on_start() -> void:
	GameManager.change_state(GameManager.STATE_DAILY_LIFE)
	get_tree().change_scene_to_file("res://src/vn/vn_scene.tscn")

func _on_investigate() -> void:
	GameManager.change_state(GameManager.STATE_INVESTIGATION)
	get_tree().change_scene_to_file("res://src/investigation/investigation_scene.tscn")

func _on_quit() -> void:
	get_tree().quit()
