class_name PlaceholderBody
extends Node2D
## Draws a hero as a coloured shape with a letter, so heroes are readable without any art
## files. HeroView swaps this out automatically when HeroData has a sprite.

var shape: HeroData.PlaceholderShape = HeroData.PlaceholderShape.CIRCLE
var fill := Color.WHITE
var outline := Color.BLACK
var accent := Color.WHITE
var letter := ""
var facing := Vector2.RIGHT:
	set(value):
		if value != facing:
			facing = value
			queue_redraw()


func setup(data: HeroData, darken: bool) -> void:
	shape = data.placeholder_shape
	fill = data.color.darkened(0.15) if darken else data.color
	outline = data.outline_color
	accent = data.accent_color
	letter = data.letter
	queue_redraw()


func _draw() -> void:
	var angle := facing.angle()
	match shape:
		HeroData.PlaceholderShape.SQUARE:
			var rect := Rect2(-28, -28, 56, 56)
			draw_rect(rect, fill)
			draw_rect(rect, outline, false, 4.0)
			draw_colored_polygon(_rotated(PackedVector2Array([Vector2(26, -8), Vector2(36, 0), Vector2(26, 8)]), angle), accent)
		HeroData.PlaceholderShape.TRIANGLE:
			var tri := _rotated(PackedVector2Array([Vector2(32, 0), Vector2(-24, -26), Vector2(-24, 26)]), angle)
			draw_colored_polygon(tri, fill)
			_draw_closed(tri, outline, 3.0)
		HeroData.PlaceholderShape.DIAMOND:
			var dia := PackedVector2Array([Vector2(0, -40), Vector2(40, 0), Vector2(0, 40), Vector2(-40, 0)])
			draw_colored_polygon(dia, fill)
			_draw_closed(dia, outline, 3.0)
			draw_line(facing * 30.0, facing * 46.0, accent, 4.0)
		_:
			draw_circle(Vector2.ZERO, 28.0, fill)
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, outline, 3.0, true)
			draw_circle(facing * 14.0, 7.0, accent)
	draw_string(ThemeDB.fallback_font, Vector2(-28, 9), letter, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 26, Color.WHITE)


func _draw_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


static func _rotated(points: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p.rotated(angle))
	return out
