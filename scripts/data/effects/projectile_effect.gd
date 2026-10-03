class_name ProjectileEffect
extends EffectData
## A moving circular hitbox that applies its payload to the first enemy hit. Walls and
## pillars destroy it. Only ranged normal attacks home; skill projectiles fly straight.

@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var speed_px_s: float = 800.0
@export_range(1.0, 100.0, 1.0, "suffix:px") var radius_px: float = 8.0
@export_range(0.0, 2000.0, 1.0, "suffix:px") var max_range_px: float = 600.0
@export var homing := false
@export var payload: Array[EffectData] = []

@export_group("Look")
@export var color := Color.WHITE
## Optional real art; when empty the projectile is drawn as a coloured circle.
@export var sprite: Texture2D


func describe() -> String:
	return "Projectile %d px/s" % roundi(speed_px_s)
