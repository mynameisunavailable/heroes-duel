class_name FxView
extends Node2D
## Draws cast telegraphs, projectiles and the local player's aim indicator, beneath the
## heroes so it never hides them. Read-only, like every view: it mirrors MatchState and
## never writes to it. Damage numbers live in DamageNumbers, above the heroes.

const ENEMY_TELEGRAPH := Color(1.0, 0.23, 0.36, 0.45)

var _state: MatchState
var _geometry: ArenaGeometry
var _local_index := 0
var _aim_skill: SkillData
var _aim_vector := Vector2.ZERO
var _aim_active := false


func setup(state: MatchState, geometry: ArenaGeometry, local_index: int) -> void:
	_state = state
	_geometry = geometry
	_local_index = local_index


## Shows where a dragged skill would land. pad is a 0..1 vector from the button centre.
func set_aim_preview(slot: int, pad: Vector2, active: bool) -> void:
	_aim_active = active
	_aim_skill = null
	if not active or _state == null:
		return
	var me := _state.heroes[_local_index]
	if slot >= 0 and slot < me.data.skills.size():
		_aim_skill = me.data.skills[slot]
		_aim_vector = pad


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _state == null:
		return
	for hero in _state.heroes:
		if hero.is_casting():
			_draw_telegraph(hero)
	if _aim_active and _aim_skill != null:
		var me := _state.heroes[_local_index]
		var aim := LocalPlayerController._pad_to_aim(_aim_skill, _aim_vector)
		var color := _aim_skill.telegraph_color
		color.a = 0.35
		_draw_skill_shape(me.pos, _aim_skill, aim, color)
	for p in _state.projectiles:
		draw_circle(p.pos, p.radius_px, p.color)
		draw_arc(p.pos, p.radius_px, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 2.0, true)


## Both players see each other's windups, drawn from simulation state only, so a
## telegraph can never reveal more than the opponent is entitled to know.
func _draw_telegraph(hero: HeroState) -> void:
	var skill: SkillData = hero.data.skills[hero.cast_slot]
	var color := skill.telegraph_color if hero.index == _local_index else ENEMY_TELEGRAPH
	_draw_skill_shape(hero.pos, skill, hero.cast_aim, color)


func _draw_skill_shape(origin: Vector2, skill: SkillData, aim: Vector2, color: Color) -> void:
	var fill := Color(color.r, color.g, color.b, color.a * 0.5)
	match skill.targeting:
		SkillData.Targeting.AROUND_SELF:
			draw_circle(origin, skill.radius_or_width_px, fill)
			draw_arc(origin, skill.radius_or_width_px, 0.0, TAU, 48, color, 3.0, true)
		SkillData.Targeting.POINT:
			var centre := origin + aim.limit_length(skill.range_px)
			draw_circle(centre, skill.radius_or_width_px, fill)
			draw_arc(centre, skill.radius_or_width_px, 0.0, TAU, 48, color, 3.0, true)
		_:
			if aim.length_squared() <= 0.0001:
				return
			var dir := aim.normalized()
			# Stop the band at the wall or pillar that would stop the skill itself.
			var half_width := skill.radius_or_width_px * 0.5
			var length := skill.range_px
			if _geometry != null:
				length = _geometry.ray_exit_distance(origin, dir, length, half_width)
			if length <= 1.0:
				return
			var side := dir.orthogonal() * half_width
			var tip := origin + dir * length
			draw_colored_polygon(PackedVector2Array([
				origin + side, tip + side, tip - side, origin - side]), color)
