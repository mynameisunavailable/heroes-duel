class_name ArenaData
extends Resource
## Arena layout in arena-local pixels (origin at the top-left of the bounding box).
## The floor must be a convex polygon; pillars are circles that block movement and
## line of sight.

@export var id: String = ""
@export var size := Vector2(1000, 480)
@export var polygon := PackedVector2Array()
@export var pillar_centers := PackedVector2Array()
@export var pillar_radius: float = 40.0
@export var spawn_points := PackedVector2Array()
@export var spawn_facings := PackedVector2Array()

@export_group("Look")
@export var floor_color := Color(0.16, 0.18, 0.23)
@export var wall_color := Color(0.45, 0.5, 0.6)
@export var pillar_color := Color(0.3, 0.33, 0.4)
## Optional real art for the floor, drawn over the bounding box.
@export var floor_texture: Texture2D
