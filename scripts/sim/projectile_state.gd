class_name ProjectileState
extends RefCounted
## A flying hitbox in the simulation. Walls and pillars destroy it; the first enemy hit
## takes its payload. Only ranged normal attacks home.

var id: int = 0
var owner_index: int = 0
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var direction := Vector2.RIGHT
var speed_px_s := 0.0
var radius_px: float = 8.0
var remaining_px: float = 0.0
var homing := false
var payload: Array[EffectData] = []
var color := Color.WHITE


static func create(p_id: int, owner: int, from: Vector2, dir: Vector2, effect: ProjectileEffect) -> ProjectileState:
	var p := ProjectileState.new()
	p.id = p_id
	p.owner_index = owner
	p.pos = from
	p.prev_pos = from
	p.direction = dir
	p.speed_px_s = effect.speed_px_s
	p.radius_px = effect.radius_px
	p.remaining_px = effect.max_range_px
	p.homing = effect.homing
	p.payload = effect.payload
	p.color = effect.color
	return p
