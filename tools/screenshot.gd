extends SceneTree
## Launches the arena, lets it play for a while, and saves PNGs of the running game.
## Needs a real display, so do not pass --headless. Run it at the base viewport size
## (--resolution 1280x720) so injected touch coordinates line up with what is drawn.
## Run: godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- --frames=140,420
##   --frames   comma-separated frame numbers to capture (default 140,420)
##   --out      output directory, relative to the project (default build)
##   --drag     skill slot to press and drag, to capture the aim indicator
##   --drag-to  "x,y" in viewport pixels to drag towards (default the arena centre)
##   --keys     physical keys to hold down, e.g. --keys=D,J, to check the bindings work

var _capture_at := PackedInt32Array([140, 420])
var _out_dir := "build"
var _drag_slot := -1
var _drag_to := Vector2(560.0, 300.0)
var _hold_keys: Array[int] = []
var _frame := 0
var _taken := 0
var _drag_started := false
var _keys_held := false
var _touch_index := 7


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_capture_at = PackedInt32Array()
			for part in arg.trim_prefix("--frames=").split(",", false):
				_capture_at.append(part.to_int())
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--drag="):
			_drag_slot = arg.trim_prefix("--drag=").to_int()
		elif arg.begins_with("--drag-to="):
			var parts := arg.trim_prefix("--drag-to=").split(",", false)
			if parts.size() == 2:
				_drag_to = Vector2(parts[0].to_float(), parts[1].to_float())
		elif arg.begins_with("--keys="):
			for name in arg.trim_prefix("--keys=").split(",", false):
				var keycode := OS.find_keycode_from_string(name.strip_edges())
				if keycode != KEY_NONE:
					_hold_keys.append(keycode)
				else:
					printerr("Unknown key: %s" % name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s" % _out_dir))
	change_scene_to_file("res://scenes/arena/arena.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	_hold_down_keys()
	_drive_drag()
	if not _capture_at.has(_frame):
		return false
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://%s/shot_%04d.png" % [_out_dir, _frame])
	var err := image.save_png(path)
	if err != OK:
		printerr("Could not save %s: %s" % [path, error_string(err)])
		return true
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	_taken += 1
	return _taken >= _capture_at.size()


## Presses the requested keys once, shortly before the first capture, and never releases
## them, so the capture shows what holding them does.
func _hold_down_keys() -> void:
	if _keys_held or _hold_keys.is_empty() or _capture_at.is_empty():
		return
	if _frame < _capture_at[0] - 30:
		return
	_keys_held = true
	for keycode in _hold_keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		event.pressed = true
		Input.parse_input_event(event)


## Presses the requested skill button a few frames before the first capture and holds a
## drag towards the target, so the shot shows the aim indicator and cancel disc.
func _drive_drag() -> void:
	if _drag_slot < 0 or _capture_at.is_empty():
		return
	var press_frame: int = _capture_at[0] - 10
	if _frame < press_frame:
		return
	var button := _find_skill_button(root, _drag_slot)
	if button == null:
		return
	var centre := button.global_position + button.size * 0.5
	if not _drag_started:
		_drag_started = true
		var press := InputEventScreenTouch.new()
		press.index = _touch_index
		press.position = centre
		press.pressed = true
		Input.parse_input_event(press)
		return
	var drag := InputEventScreenDrag.new()
	drag.index = _touch_index
	drag.position = centre.lerp(_drag_to, clampf((_frame - press_frame) / 8.0, 0.0, 1.0))
	Input.parse_input_event(drag)


func _find_skill_button(node: Node, slot: int) -> Control:
	if node is SkillButton and (node as SkillButton).slot == slot:
		return node as Control
	for child in node.get_children():
		var found := _find_skill_button(child, slot)
		if found != null:
			return found
	return null
