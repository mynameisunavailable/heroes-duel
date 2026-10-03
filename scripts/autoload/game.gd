extends Node
## Autoload "Game": hero roster, the next match's configuration and scene flow.

const ROSTER_PATH := "res://data/roster.tres"
const ARENA_SCENE := "res://scenes/arena/arena.tscn"

var roster: HeroRoster
var next_match: MatchConfig


func _ready() -> void:
	InputBindings.ensure_defaults()
	roster = load(ROSTER_PATH) as HeroRoster
	if roster == null:
		push_error("Hero roster missing or invalid: %s" % ROSTER_PATH)
	next_match = MatchConfig.default_vs_ai()
	next_match.ai_difficulty = UserSettings.ai_difficulty


func start_match(config: MatchConfig) -> void:
	next_match = config
	get_tree().change_scene_to_file(ARENA_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_restart"):
		get_tree().reload_current_scene()
