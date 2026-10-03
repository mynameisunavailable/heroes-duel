class_name DamageNumbers
extends Node2D
## Floating damage numbers. Sits above the heroes so hits stay readable, and is driven
## entirely by DAMAGE events, never by reading hero HP.

const LIFE_S := 0.8
const RISE_PX := 48.0
const BIG_HIT := 60

var _numbers: Array[Dictionary] = []


func on_sim_event(ev: SimEvent) -> void:
	if ev.kind != SimEvent.Kind.DAMAGE or ev.amount <= 0:
		return
	_numbers.append({
		"pos": ev.pos + Vector2(randf_range(-12.0, 12.0), -44.0),
		"text": str(ev.amount),
		"life": LIFE_S,
		"big": ev.amount >= BIG_HIT,
	})


func clear() -> void:
	_numbers.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _numbers.is_empty():
		return
	var i := _numbers.size() - 1
	while i >= 0:
		_numbers[i]["life"] -= delta
		if _numbers[i]["life"] <= 0.0:
			_numbers.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for n in _numbers:
		var t: float = 1.0 - float(n["life"]) / LIFE_S
		var font_size: int = 36 if n["big"] else 26
		var pos: Vector2 = n["pos"] - Vector2(0.0, RISE_PX * t)
		var alpha := 1.0 - t * t
		draw_string(font, pos + Vector2(2, 2), n["text"], HORIZONTAL_ALIGNMENT_CENTER, 0.0, font_size, Color(0, 0, 0, alpha * 0.7))
		draw_string(font, pos, n["text"], HORIZONTAL_ALIGNMENT_CENTER, 0.0, font_size, Color(1.0, 0.95, 0.6, alpha))
