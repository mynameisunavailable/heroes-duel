extends Node
## Autoload "UserSettings": player preferences, persisted to user://settings.cfg.

signal changed(key: StringName)

const PATH := "user://settings.cfg"

var haptics_enabled := true
var reduce_shake := false
var master_volume_db := 0.0
var ai_difficulty: int = 1


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	haptics_enabled = cfg.get_value("feel", "haptics", haptics_enabled)
	reduce_shake = cfg.get_value("feel", "reduce_shake", reduce_shake)
	master_volume_db = cfg.get_value("audio", "master_db", master_volume_db)
	ai_difficulty = cfg.get_value("game", "ai_difficulty", ai_difficulty)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("feel", "haptics", haptics_enabled)
	cfg.set_value("feel", "reduce_shake", reduce_shake)
	cfg.set_value("audio", "master_db", master_volume_db)
	cfg.set_value("game", "ai_difficulty", ai_difficulty)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))


func set_value(key: StringName, value: Variant) -> void:
	set(key, value)
	save_settings()
	changed.emit(key)
