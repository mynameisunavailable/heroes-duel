extends Node
## Main scene. Routes to the right starting point for how the game was launched.
## Milestone M2 inserts the main menu and hero select here.


func _ready() -> void:
	if AppEnv.is_dedicated_server():
		print("Heroes Duel: dedicated server mode is planned for milestone M6.")
		get_tree().quit(0)
		return
	Game.start_hero_select.call_deferred()
