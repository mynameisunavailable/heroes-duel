class_name HpBar
extends Control
## Top-of-screen HP bar with the hero name, round-win pips, a lingering "ghost damage"
## chunk and, for the opponent, skill-readiness pips. Mirrored bars fill from the right.

const GHOST_HOLD_S := 0.4
const GHOST_DRAIN_PER_S := 1.5
const BAR_HEIGHT := 26.0
const ROUNDS_TO_WIN := 2

@export var mirrored := false

var hero_name := ""
var team_color := Color.WHITE
var ratio := 1.0
var ghost := 1.0
var wins := 0
var pips: Array[bool] = []
var _ghost_hold := 0.0


func setup(p_name: String, p_team_color: Color) -> void:
	hero_name = p_name
	team_color = p_team_color
	queue_redraw()


func set_values(p_ratio: float, p_wins: int, p_pips: Array[bool]) -> void:
	if p_ratio < ratio:
		_ghost_hold = GHOST_HOLD_S
	if p_ratio > ghost:
		ghost = p_ratio
	if not is_equal_approx(p_ratio, ratio) or p_wins != wins or p_pips != pips:
		ratio = p_ratio
		wins = p_wins
		pips = p_pips
		queue_redraw()


func _process(delta: float) -> void:
	if ghost <= ratio:
		return
	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	else:
		ghost = maxf(ratio, ghost - GHOST_DRAIN_PER_S * delta)
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(0.0, size.y - BAR_HEIGHT, size.x, BAR_HEIGHT)
	draw_rect(bar, Palette.HUD_BG)
	_draw_fill(bar, ghost, Palette.GHOST)
	_draw_fill(bar, ratio, team_color)
	draw_rect(bar, Color(1, 1, 1, 0.5), false, 2.0)

	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 16.0), hero_name, align, size.x, 18, Color.WHITE)

	# Round-win pips sit on the inner end, toward the timer.
	for i in ROUNDS_TO_WIN:
		var x := 12.0 + i * 20.0 if mirrored else size.x - 12.0 - i * 20.0
		var p := Vector2(x, 9.0)
		if i < wins:
			draw_circle(p, 7.0, Color(1.0, 0.85, 0.3))
		else:
			draw_arc(p, 7.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0, true)

	# Skill-readiness pips in the middle: filled = ready.
	for i in pips.size():
		var q := Vector2(size.x * 0.5 + (i - (pips.size() - 1) * 0.5) * 16.0, 9.0)
		if pips[i]:
			draw_circle(q, 5.0, team_color)
		else:
			draw_arc(q, 5.0, 0.0, TAU, 16, team_color, 1.5, true)


func _draw_fill(bar: Rect2, value: float, color: Color) -> void:
	var w := bar.size.x * clampf(value, 0.0, 1.0)
	var x := bar.position.x + (bar.size.x - w if mirrored else 0.0)
	draw_rect(Rect2(x, bar.position.y, w, bar.size.y), color)
