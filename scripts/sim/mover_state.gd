class_name MoverState
extends RefCounted
## Forced movement of a hero: a dash they cast, or a knockback pushing them away.
## While a mover is active the hero cannot move, attack or cast of their own accord.

enum Kind { DASH, KNOCKBACK }

var active := false
var kind: Kind = Kind.DASH
var direction := Vector2.RIGHT
var speed_px_s := 0.0
var remaining_px := 0.0
var half_width := 0.0
## Dash only: stop at the first enemy touched instead of passing through.
var stop_on_hit := false
## Ignore hero-vs-hero separation, so the dash can cross the enemy's body.
var pass_through := false
var payload: Array[EffectData] = []
## Heroes already hit by this mover, so a pass-through dash hits each one once.
var hit_indices := PackedInt32Array()


func start_dash(effect: DashEffect, dir: Vector2) -> void:
	active = true
	kind = Kind.DASH
	direction = dir
	speed_px_s = effect.speed_px_s
	remaining_px = effect.distance_px
	half_width = effect.width_px * 0.5
	stop_on_hit = effect.mode == DashEffect.Mode.STOP_ON_HIT
	pass_through = effect.mode == DashEffect.Mode.PASS_THROUGH
	payload = effect.payload
	hit_indices = PackedInt32Array()


func start_knockback(distance_px: float, travel_s: float, dir: Vector2) -> void:
	active = true
	kind = Kind.KNOCKBACK
	direction = dir
	speed_px_s = distance_px / maxf(travel_s, 0.01)
	remaining_px = distance_px
	half_width = 0.0
	stop_on_hit = false
	pass_through = false
	payload = []
	hit_indices = PackedInt32Array()


func clear() -> void:
	active = false
	remaining_px = 0.0
	payload = []
	hit_indices = PackedInt32Array()
