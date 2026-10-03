class_name HeroState
extends RefCounted
## Mutable simulation state of one hero. Plain data: no nodes, no input, no textures.

var index: int = 0
var data: HeroData

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var facing := Vector2.RIGHT
## Pixels per second over the last tick.
var velocity := Vector2.ZERO

var hp: int = 0
var max_hp: int = 0
var alive := true

var attack_cd: int = 0
var windup_ticks: int = 0

var skill_cds: CooldownTracker
var gcd_ticks: int = 0
var cast_slot: int = -1
var cast_ticks_left: int = 0
var cast_aim := Vector2.ZERO
var cast_manual := false

var stun_ticks: int = 0
var slow_pct: float = 0.0
var slow_ticks: int = 0
## Active dash or knockback. While it runs the hero cannot act.
var mover := MoverState.new()

var buffered_slot: int = -1
var buffered_ticks: int = 0
var buffered_aim := Vector2.ZERO
var buffered_manual := false

## Total damage dealt this match (tiebreak input). Not reset between rounds.
var damage_dealt: int = 0

## Prebuilt normal-attack payload (and arrow, for ranged heroes), so attacking allocates
## nothing per swing.
var attack_payload: Array[EffectData] = []
var attack_projectile: ProjectileEffect


func _init(p_index: int, p_data: HeroData) -> void:
	index = p_index
	data = p_data
	max_hp = p_data.max_hp
	hp = max_hp
	skill_cds = CooldownTracker.new(p_data.skills.size())
	var hit := DamageEffect.new()
	hit.amount = p_data.attack_damage
	attack_payload = [hit]
	if p_data.attack_type == HeroData.AttackType.PROJECTILE:
		attack_projectile = _build_attack_projectile(p_data, attack_payload)


static func _build_attack_projectile(p_data: HeroData, payload: Array[EffectData]) -> ProjectileEffect:
	var shot := ProjectileEffect.new()
	shot.speed_px_s = p_data.projectile_speed
	shot.radius_px = p_data.projectile_radius
	shot.max_range_px = p_data.attack_range * 1.5
	shot.homing = true
	shot.color = p_data.color
	shot.payload = payload
	return shot


func reset_for_round(spawn: Vector2, face: Vector2) -> void:
	pos = spawn
	prev_pos = spawn
	facing = face.normalized() if face.length_squared() > 0.0 else Vector2.RIGHT
	velocity = Vector2.ZERO
	hp = max_hp
	alive = true
	attack_cd = 0
	windup_ticks = 0
	skill_cds.reset_all(SimConst.ROUND_START_SKILL_CD_TICKS)
	gcd_ticks = 0
	clear_cast()
	stun_ticks = 0
	slow_pct = 0.0
	slow_ticks = 0
	mover.clear()
	clear_buffer()


func clear_cast() -> void:
	cast_slot = -1
	cast_ticks_left = 0
	cast_aim = Vector2.ZERO
	cast_manual = false


func clear_buffer() -> void:
	buffered_slot = -1
	buffered_ticks = 0
	buffered_aim = Vector2.ZERO
	buffered_manual = false


func is_casting() -> bool:
	return cast_slot >= 0


func is_stunned() -> bool:
	return stun_ticks > 0


## True while the hero cannot act of their own accord.
func is_busy() -> bool:
	return is_stunned() or is_casting() or mover.active


func speed_multiplier() -> float:
	if slow_ticks > 0:
		return maxf(1.0 - slow_pct, SimConst.MIN_SPEED_FACTOR)
	return 1.0


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)
