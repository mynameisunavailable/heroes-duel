class_name FloatingJoystick
extends Control
## Floating virtual joystick. The base appears under the thumb anywhere in this zone and
## trails the thumb when dragged past its radius. It handles touch events only (on
## desktop the mouse drives it through "emulate touch from mouse") and tracks its own
## finger, so it keeps working while other fingers press buttons.
## Not named VirtualJoystick: Godot 4.7 ships a built-in class with that name.

signal vector_changed(vector: Vector2)

@export var base_radius := 80.0
@export var knob_radius := 36.0
@export var dead_zone_px := 12.0
@export var idle_alpha := 0.35
@export var active_alpha := 0.5

## Centre of the idle "ghost" stick, measured from the zone's bottom-left corner.
var idle_centre_offset := Vector2(170, -160)
## Current output: a unit direction, or zero inside the dead zone.
var output := Vector2.ZERO

var _touch_index := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_base = touch.position
			_knob = touch.position
			_recompute()
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			reset()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		_knob = drag.position
		var offset := _knob - _base
		if offset.length() > base_radius:
			_base = _knob - offset.normalized() * base_radius
		_recompute()
		accept_event()


func reset() -> void:
	_touch_index = -1
	_base = Vector2.ZERO
	_knob = Vector2.ZERO
	_recompute()


func _recompute() -> void:
	var offset := _knob - _base
	var new_output := Vector2.ZERO
	if _touch_index != -1 and offset.length() > dead_zone_px:
		new_output = offset.normalized()
	if new_output != output:
		output = new_output
		vector_changed.emit(output)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if _touch_index != -1:
			reset()


func _draw() -> void:
	if _touch_index == -1:
		var ghost := Vector2(idle_centre_offset.x, size.y + idle_centre_offset.y)
		draw_arc(ghost, base_radius, 0.0, TAU, 48, Color(1, 1, 1, idle_alpha), 3.0, true)
		draw_circle(ghost, knob_radius, Color(1, 1, 1, idle_alpha * 0.5))
	else:
		draw_arc(_base, base_radius, 0.0, TAU, 48, Color(1, 1, 1, active_alpha), 3.0, true)
		draw_circle(_knob, knob_radius, Color(1, 1, 1, active_alpha * 0.6))
