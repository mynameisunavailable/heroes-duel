class_name CancelDisc
extends Control
## The red X that appears while a skill is being drag-aimed. Releasing the drag over it
## cancels the cast without spending the cooldown.
##
## It does not handle input itself: the finger that started on a skill button keeps
## receiving every later event from that button, so SkillButton decides whether a
## release landed here, using the rect published by the HUD.

const RADIUS := 55.0

var hovered := false:
	set(value):
		if value != hovered:
			hovered = value
			queue_redraw()


func centre_global() -> Vector2:
	return global_position + size * 0.5


func _draw() -> void:
	var c := size * 0.5
	var fill := Color(0.75, 0.15, 0.2, 0.85) if hovered else Color(0.2, 0.08, 0.1, 0.7)
	draw_circle(c, RADIUS, fill)
	draw_arc(c, RADIUS, 0.0, TAU, 48, Palette.DENIED, 3.0, true)
	var arm := RADIUS * 0.42
	draw_line(c + Vector2(-arm, -arm), c + Vector2(arm, arm), Color.WHITE, 5.0, true)
	draw_line(c + Vector2(arm, -arm), c + Vector2(-arm, arm), Color.WHITE, 5.0, true)
