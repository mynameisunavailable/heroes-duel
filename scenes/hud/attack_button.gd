class_name AttackButton
extends Control
## Round attack button. Hold to auto-attack the enemy (and walk into range when the
## joystick is idle); a quick tap queues a single attack. Handles touch events only and
## tracks its own finger for multitouch.

signal held_changed(held: bool)
signal tapped

const TAP_MAX_MS := 200
const DENY_FLASH_S := 0.25

var _touch_index := -1
var _pressed_at_ms := 0
var _deny_left := 0.0


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= size.x * 0.5


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _touch_index == -1:
		_touch_index = touch.index
		_pressed_at_ms = Time.get_ticks_msec()
		held_changed.emit(true)
		queue_redraw()
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		var quick := Time.get_ticks_msec() - _pressed_at_ms <= TAP_MAX_MS
		_release()
		if quick and not touch.canceled:
			tapped.emit()
		accept_event()


func reset() -> void:
	_release()


## Flashes the button red, e.g. when a tap was out of range.
func deny() -> void:
	_deny_left = DENY_FLASH_S
	queue_redraw()


func _release() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	held_changed.emit(false)
	queue_redraw()


func _process(delta: float) -> void:
	if _deny_left > 0.0:
		_deny_left = maxf(_deny_left - delta, 0.0)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release()


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	var held := _touch_index != -1
	draw_circle(c, r, Color(1, 1, 1, 0.8 if held else 0.5))
	if _deny_left > 0.0:
		draw_arc(c, r - 3.0, 0.0, TAU, 48, Palette.DENIED, 6.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 32
	var baseline := c.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(0.0, baseline), tr("ATK"), HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Palette.TEXT_DARK)
