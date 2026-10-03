class_name AIController
extends HeroController
## Simple AI that plays a hero's AIProfile: chase or kite, hold attack when in range, and
## quick-cast a skill once it has been ready for a difficulty-based reaction delay.
## It reads only MatchState, never the other player's raw input.
## Milestone M1 replaces the skill choice with per-skill rules from the design.

enum Difficulty { EASY, NORMAL }

const DECISION_TICKS := 6
## Ticks a skill must have been ready before the AI reacts, per difficulty.
const REACTION_TICKS := [27, 18]
## Within this distance a retreat also steers toward the arena centre to avoid corners.
const CENTRE_PULL_DISTANCE := 260.0

var profile: AIProfile
var difficulty: int = Difficulty.NORMAL
## Used to avoid aiming skills into a pillar. Optional; without it the AI shoots blind.
var geometry: ArenaGeometry

var _rng := RandomNumberGenerator.new()
var _move := Vector2.ZERO
var _strafe_sign := 1.0
var _strafe_ticks_left := 0
var _seen_ready_for := PackedInt32Array()


func _init(p_profile: AIProfile, p_difficulty: int, p_seed: int, p_geometry: ArenaGeometry = null) -> void:
	profile = p_profile
	difficulty = clampi(p_difficulty, 0, REACTION_TICKS.size() - 1)
	_rng.seed = p_seed
	geometry = p_geometry


func build_command(tick: int, state: MatchState) -> HeroCommand:
	var cmd := HeroCommand.idle(tick)
	if state.phase != MatchState.Phase.FIGHT:
		return cmd
	var me := state.heroes[hero_index]
	var foe := state.enemy_of(hero_index)
	if not me.alive or not foe.alive:
		return cmd

	var to_foe := foe.pos - me.pos
	var dist := to_foe.length()
	# Every AI decides on the same ticks. Staggering them by hero index would give one
	# side a permanent one-decision head start, which alone decides every mirror match.
	if tick % DECISION_TICKS == 0:
		_decide(me, to_foe, dist, state.arena.size * 0.5)
	cmd.move = _move
	cmd.attack_held = dist <= me.data.attack_range or profile.move_style == AIProfile.MoveStyle.CHASE
	cmd.skill_index = _pick_skill(me, foe, dist)
	return cmd


func _decide(me: HeroState, to_foe: Vector2, dist: float, arena_centre: Vector2) -> void:
	var dir: Vector2 = to_foe / dist if dist > 0.001 else Vector2.RIGHT
	if profile.move_style == AIProfile.MoveStyle.KITE:
		if dist < profile.retreat_below_px:
			_move = -dir
			var to_centre := arena_centre - me.pos
			if to_centre.length() > CENTRE_PULL_DISTANCE:
				_move = (_move + to_centre.normalized() * 0.8).normalized()
		elif dist > profile.preferred_max_px:
			_move = dir
		else:
			_strafe_ticks_left -= DECISION_TICKS
			if _strafe_ticks_left <= 0:
				_strafe_sign = -_strafe_sign
				_strafe_ticks_left = _rng.randi_range(
					SimConst.to_ticks(profile.strafe_switch_min_s),
					SimConst.to_ticks(profile.strafe_switch_max_s))
			_move = dir.orthogonal() * _strafe_sign
	elif profile.move_style == AIProfile.MoveStyle.RUSH_CURVE:
		if dist > profile.preferred_max_px:
			_move = (dir + dir.orthogonal() * 0.35 * _strafe_sign).normalized()
		else:
			_move = Vector2.ZERO
	else:
		_move = dir if dist > profile.preferred_max_px else Vector2.ZERO


func _pick_skill(me: HeroState, foe: HeroState, dist: float) -> int:
	var skills := me.data.skills
	if _seen_ready_for.size() != skills.size():
		_seen_ready_for.resize(skills.size())
		_seen_ready_for.fill(0)
	var can_cast := me.gcd_ticks == 0 and not me.is_casting() and not me.is_stunned()
	var choice := -1
	for i in skills.size():
		if can_cast and me.skill_cds.is_ready(i):
			_seen_ready_for[i] += 1
		else:
			_seen_ready_for[i] = 0
		if choice < 0 and _seen_ready_for[i] >= REACTION_TICKS[difficulty] and _wants_skill(skills[i], me, foe, dist):
			choice = i
	if choice >= 0:
		_seen_ready_for[choice] = 0
	return choice


func _wants_skill(skill: SkillData, me: HeroState, foe: HeroState, dist: float) -> bool:
	if skill.targeting == SkillData.Targeting.AROUND_SELF:
		return dist <= skill.radius_or_width_px + SimConst.HURT_RADIUS
	if skill.quick_aim == SkillData.QuickAim.AWAY_OR_JOYSTICK:
		# Escape skills: only when the enemy is close.
		return dist < 150.0
	if dist > _effective_range(skill, foe):
		return false
	# Do not throw a skillshot or charge into a pillar.
	if geometry != null and skill.targeting == SkillData.Targeting.DIRECTION:
		return not geometry.segment_blocked_by_pillar(me.pos, foe.pos, skill.radius_or_width_px * 0.5)
	return true


## A charge that stops on its first target only connects if it out-runs the target over
## its wind-up and travel. Firing at maximum range just feeds the enemy a free escape, so
## the usable range is the nominal one minus the ground the target can cover.
static func _effective_range(skill: SkillData, foe: HeroState) -> float:
	for effect in skill.effects:
		if effect is DashEffect and (effect as DashEffect).mode == DashEffect.Mode.STOP_ON_HIT:
			var dash := effect as DashEffect
			var travel_s := skill.cast_time_s + dash.distance_px / maxf(dash.speed_px_s, 1.0)
			var escape_px := foe.data.move_speed * travel_s
			return maxf(skill.range_px - escape_px, SimConst.BODY_RADIUS * 2.0)
	return skill.range_px
