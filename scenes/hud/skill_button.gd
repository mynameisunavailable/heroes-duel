class_name SkillButton
extends Control
## One skill button. Tap = quick cast. Drag beyond the threshold = manual aim, cast on
## release; dragging back to the centre and releasing cancels. Shows the cooldown as a
## clockwise sweep with the seconds remaining. Handles touch events only.

signal released(slot: int, pad: Vector2, manual: bool)
signal aim_changed(slot: int, pad: Vector2, active: bool)
signal cancel_hovered(hovered: bool)

const DENY_TIME_S := 0.15

@export var drag_threshold_px := 24.0
@export var aim_pad_radius_px := 110.0

## Set by the HUD from the player's settings. Kept as a plain property rather than
## reading the autoload here, so this widget stays self-contained and can be compiled
## and exercised without the rest of the game running.
var haptics_enabled := true

var slot := -1
var skill: SkillData
## Cancel zone published by the HUD. The finger that pressed this button keeps receiving
## its own drag and release events, so this button decides whether a release landed
## on the shared cancel disc rather than the disc handling input itself.
var cancel_centre := Vector2.ZERO
var cancel_radius := 0.0

var _touch_index := -1
var _drag_pos := Vector2.ZERO
var _dragging := false
var _cd_fraction := 0.0
var _cd_seconds := 0.0
var _deny_left := 0.0
var _tween: Tween


func setup(p_slot: int, p_skill: SkillData) -> void:
	slot = p_slot
	skill = p_skill
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= size.x * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_drag_pos = touch.position
			_dragging = false
			queue_redraw()
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_finish(touch.position, touch.canceled)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		_drag_pos = drag.position
		if not _dragging and _drag_pos.distance_to(size * 0.5) > drag_threshold_px:
			_dragging = true
		if _dragging:
			aim_changed.emit(slot, _pad(), true)
			cancel_hovered.emit(_over_cancel(_drag_pos))
		queue_redraw()
		accept_event()


func reset() -> void:
	if _touch_index != -1 and _dragging:
		aim_changed.emit(slot, Vector2.ZERO, false)
		cancel_hovered.emit(false)
	_touch_index = -1
	_dragging = false
	queue_redraw()


## True when a point in this button's local space lies over the HUD's cancel disc.
func _over_cancel(local: Vector2) -> bool:
	if cancel_radius <= 0.0:
		return false
	return (global_position + local).distance_to(cancel_centre) <= cancel_radius


func set_cooldown(fraction: float, seconds_left: float) -> void:
	var was_ready := _cd_fraction <= 0.0
	if not is_equal_approx(fraction, _cd_fraction) or not is_equal_approx(seconds_left, _cd_seconds):
		_cd_fraction = fraction
		_cd_seconds = seconds_left
		queue_redraw()
	if fraction <= 0.0 and not was_ready:
		_play_ready_pulse()


## Wobbles the button: pressed while on cooldown.
func deny() -> void:
	_deny_left = DENY_TIME_S
	Haptics.pulse(Haptics.Kind.SELECTION, haptics_enabled)
	queue_redraw()


func _finish(pos: Vector2, canceled: bool) -> void:
	_drag_pos = pos
	var was_dragging := _dragging
	var cancel := canceled
	if was_dragging and (pos.distance_to(size * 0.5) <= drag_threshold_px or _over_cancel(pos)):
		cancel = true
	var pad := _pad()
	_touch_index = -1
	_dragging = false
	if was_dragging:
		aim_changed.emit(slot, Vector2.ZERO, false)
		cancel_hovered.emit(false)
	if not cancel:
		released.emit(slot, pad if was_dragging else Vector2.ZERO, was_dragging)
	queue_redraw()


## Drag vector from the button centre, mapped to length 0..1 across the aim pad.
func _pad() -> Vector2:
	var offset := _drag_pos - size * 0.5
	var d := offset.length()
	if d <= 0.001:
		return Vector2.ZERO
	var t := clampf((d - drag_threshold_px) / (aim_pad_radius_px - drag_threshold_px), 0.0, 1.0)
	return offset / d * t


func _play_ready_pulse() -> void:
	pivot_offset = size * 0.5
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	Haptics.pulse(Haptics.Kind.LIGHT, haptics_enabled)


func _process(delta: float) -> void:
	if _deny_left > 0.0:
		_deny_left = maxf(_deny_left - delta, 0.0)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		reset()


func _draw() -> void:
	if skill == null:
		return
	var c := size * 0.5
	var r := size.x * 0.5
	if _deny_left > 0.0:
		c.x += sin(_deny_left * 90.0) * 8.0 * (_deny_left / DENY_TIME_S)
	if skill.icon != null:
		draw_texture_rect(skill.icon, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		var disc := skill.telegraph_color
		disc.a = 0.9
		draw_circle(c, r, disc)
		_draw_centred_text(skill.abbrev, c, 30, Color.WHITE)
	if _cd_fraction > 0.0:
		draw_circle(c, r, Color(0.1, 0.1, 0.12, 0.6))
		_draw_sweep(c, r, _cd_fraction, Color(0, 0, 0, 0.45))
		var label := "%d" % ceili(_cd_seconds) if _cd_seconds >= 1.0 else "%.1f" % _cd_seconds
		_draw_centred_text(label, c, 34, Color.WHITE)
	if _dragging:
		draw_arc(size * 0.5, aim_pad_radius_px, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		draw_circle(_drag_pos, 18.0, Color(1, 1, 1, 0.7))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)


## Wedge covering `fraction` of the disc, clockwise from 12 o'clock.
func _draw_sweep(c: Vector2, r: float, fraction: float, color: Color) -> void:
	var f := clampf(fraction, 0.0, 0.999)
	var steps := maxi(2, ceili(48.0 * f))
	var points := PackedVector2Array([c])
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * f * float(i) / float(steps)
		points.append(c + Vector2.from_angle(a) * r)
	draw_colored_polygon(points, color)


func _draw_centred_text(text: String, c: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var baseline := c.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(c.x - size.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
