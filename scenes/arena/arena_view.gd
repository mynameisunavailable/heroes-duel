class_name ArenaView
extends Node2D
## Draws the arena floor, walls and pillars from ArenaData. Placeholder art: a floor
## texture in ArenaData replaces the flat floor colour with no code change.

var arena: ArenaData


func setup(p_arena: ArenaData) -> void:
	arena = p_arena
	queue_redraw()


func _draw() -> void:
	if arena == null or arena.polygon.size() < 3:
		return
	# A floor image from the arena's data, or one dropped in art/arena/<id>.png.
	var floor_texture := ArtLibrary.arena_floor(arena)
	if floor_texture != null:
		draw_texture_rect(floor_texture, Rect2(Vector2.ZERO, arena.size), false)
	else:
		draw_colored_polygon(arena.polygon, arena.floor_color)
	var outline := arena.polygon.duplicate()
	outline.append(arena.polygon[0])
	draw_polyline(outline, arena.wall_color, 6.0, true)
	var mid_x := arena.size.x * 0.5
	draw_line(Vector2(mid_x, 0.0), Vector2(mid_x, arena.size.y), Color(1, 1, 1, 0.06), 2.0)
	for c in arena.pillar_centers:
		draw_circle(c, arena.pillar_radius, arena.pillar_color)
		draw_arc(c, arena.pillar_radius, 0.0, TAU, 40, arena.wall_color, 3.0, true)
	for p in arena.spawn_points:
		draw_circle(p, 6.0, Color(1, 1, 1, 0.3))
