class_name InputBindings
extends RefCounted
## Registers the default keyboard bindings at startup. Keeping them in code keeps
## project.godot small and lets a settings screen remap them later.

const DEFAULTS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"attack": [KEY_J, KEY_SPACE],
	&"skill_1": [KEY_K],
	&"skill_2": [KEY_L],
	&"skill_3": [KEY_SEMICOLON],
	&"skill_at_cursor_1": [KEY_Q],
	&"skill_at_cursor_2": [KEY_E],
	&"skill_at_cursor_3": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P],
	&"debug_restart": [KEY_F3],
}


static func ensure_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		for keycode: int in DEFAULTS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
