class_name CombatSim
extends RefCounted
## The authoritative fixed-tick duel simulation. It reads only HeroCommands and data
## resources and writes only MatchState, so the same code can run offline against the
## AI, on a headless server, or several times per frame for client-side prediction.

var state: MatchState
var geometry: ArenaGeometry
var _emit_events := true
var _next_projectile_id := 0
## Hits decided this tick, applied together once every hero has acted.
var _pending_hits: Array[Dictionary] = []


func _init(p_arena: ArenaData, p_heroes: Array[HeroData], p_seed: int) -> void:
	state = MatchState.new()
	state.arena = p_arena
	state.rng_seed = p_seed
	geometry = ArenaGeometry.new(p_arena)
	for i in p_heroes.size():
		state.heroes.append(HeroState.new(i, p_heroes[i]))
	reset_round()


func reset_round() -> void:
	state.phase = MatchState.Phase.PRE_ROUND
	state.phase_ticks = 0
	state.round_tick = 0
	state.round_result = MatchState.RESULT_NONE
	state.projectiles.clear()
	_pending_hits.clear()
	for h in state.heroes:
		h.reset_for_round(state.arena.spawn_points[h.index], state.arena.spawn_facings[h.index])
	emit_event(SimEvent.Kind.ROUND_PHASE, -1)


## Advances the match by one tick. Pass emit_events = false when re-simulating ticks
## during network reconciliation, so presentation does not replay effects.
func step(commands: Array[HeroCommand], emit_events: bool = true) -> void:
	_emit_events = emit_events
	state.events.clear()
	state.tick += 1
	for h in state.heroes:
		h.prev_pos = h.pos
	for p in state.projectiles:
		p.prev_pos = p.pos

	match state.phase:
		MatchState.Phase.PRE_ROUND:
			state.phase_ticks += 1
			if state.phase_ticks >= SimConst.PRE_ROUND_TICKS:
				state.phase = MatchState.Phase.FIGHT
				state.phase_ticks = 0
				emit_event(SimEvent.Kind.ROUND_PHASE, -1)
		MatchState.Phase.FIGHT:
			_step_fight(commands)
		MatchState.Phase.ROUND_OVER:
			state.phase_ticks += 1
			if state.phase_ticks >= SimConst.ROUND_OVER_TICKS:
				RoundRules.advance_after_round(self)
		MatchState.Phase.MATCH_OVER:
			state.phase_ticks += 1

	_emit_events = true


func _step_fight(commands: Array[HeroCommand]) -> void:
	# Everything a hero does is decided against the same start-of-tick positions, and only
	# then applied. Resolving one hero completely before the next would let whoever ran
	# second measure range against an opponent who had already stepped closer, which is
	# worth about one tick of reach and silently decides every mirror match: two knights
	# charging head-on would always trade in the same direction.
	_advance_movers()
	var walk: Array[Vector2] = []
	walk.resize(state.heroes.size())
	for i in state.heroes.size():
		var cmd: HeroCommand = commands[i] if i < commands.size() else HeroCommand.idle(state.tick)
		walk[i] = _apply_command(state.heroes[i], cmd)
	_flush_hits()
	for i in state.heroes.size():
		_apply_walk(state.heroes[i], walk[i])
	_separate_heroes()
	for h in state.heroes:
		h.pos = geometry.constrain_circle(h.pos, SimConst.BODY_RADIUS)
		h.velocity = (h.pos - h.prev_pos) * SimConst.TICK_RATE
	_advance_projectiles()
	_flush_hits()
	for h in state.heroes:
		_tick_timers(h)
	state.round_tick += 1
	RoundRules.check_round_end(self)


## Phase 1: resolves this hero's casts, dashes and attacks, and returns the direction it
## wants to walk. Walking itself is applied later, in _apply_walk.
func _apply_command(h: HeroState, cmd: HeroCommand) -> Vector2:
	if not h.alive or h.is_stunned():
		return Vector2.ZERO
	var foe := state.enemy_of(h.index)

	if h.mover.active:
		# Already advanced this tick by _advance_movers.
		return Vector2.ZERO

	if h.is_casting():
		# Rooted: no movement or attacks. A new press is buffered or denied.
		if cmd.skill_index >= 0:
			_try_skill(h, cmd.skill_index, cmd.aim, cmd.manual_aim, cmd.move, foe)
		_advance_cast(h, foe)
		return Vector2.ZERO

	if cmd.skill_index >= 0:
		_try_skill(h, cmd.skill_index, cmd.aim, cmd.manual_aim, cmd.move, foe)
	elif h.buffered_slot >= 0 and _can_cast_now(h, h.buffered_slot):
		var slot := h.buffered_slot
		var aim := h.buffered_aim
		var manual := h.buffered_manual
		h.clear_buffer()
		_try_skill(h, slot, aim, manual, cmd.move, foe)
	if h.is_casting() or h.mover.active:
		return Vector2.ZERO

	_update_attack(h, cmd, foe)
	return _desired_walk(h, cmd, foe)


# --- Skills ---------------------------------------------------------------------

func _try_skill(h: HeroState, slot: int, aim: Vector2, manual: bool, move: Vector2, foe: HeroState) -> void:
	if slot < 0 or slot >= h.data.skills.size():
		return
	if _can_cast_now(h, slot):
		_start_cast(h, slot, aim, manual, move, foe)
	elif _ticks_until_castable(h, slot) <= SimConst.BUFFER_TICKS:
		h.buffered_slot = slot
		# One extra tick so the press survives until the first tick it becomes legal.
		h.buffered_ticks = SimConst.BUFFER_TICKS + 1
		h.buffered_aim = aim
		h.buffered_manual = manual
		emit_event(SimEvent.Kind.SKILL_BUFFERED, h.index, -1, slot)
	else:
		emit_event(SimEvent.Kind.SKILL_DENIED, h.index, -1, slot)


func _can_cast_now(h: HeroState, slot: int) -> bool:
	return not h.is_busy() and h.gcd_ticks == 0 and h.skill_cds.is_ready(slot)


func _ticks_until_castable(h: HeroState, slot: int) -> int:
	var wait := maxi(h.skill_cds.remaining(slot), h.gcd_ticks)
	if h.is_casting():
		# The global cooldown starts when the current cast fires.
		var after_fire := h.cast_ticks_left - 1 + SimConst.GCD_TICKS
		if slot == h.cast_slot:
			after_fire = h.cast_ticks_left - 1 + h.data.skills[slot].cooldown_ticks()
		wait = maxi(wait, after_fire)
	return maxi(wait, h.stun_ticks)


func _start_cast(h: HeroState, slot: int, aim: Vector2, manual: bool, move: Vector2, foe: HeroState) -> void:
	var skill: SkillData = h.data.skills[slot]
	if h.windup_ticks > 0:
		# A skill press cancels an attack windup without spending the attack timer.
		h.windup_ticks = 0
		h.attack_cd = 0
	h.clear_buffer()
	h.cast_slot = slot
	h.cast_manual = manual and aim.length_squared() > 0.0
	h.cast_aim = aim if h.cast_manual else _quick_aim(h, skill, move, foe)
	h.cast_ticks_left = skill.cast_ticks()
	_face(h, h.cast_aim)
	emit_event(SimEvent.Kind.SKILL_CAST_STARTED, h.index, foe.index, slot)
	if h.cast_ticks_left <= 0:
		_fire_skill(h)


func _advance_cast(h: HeroState, foe: HeroState) -> void:
	var skill: SkillData = h.data.skills[h.cast_slot]
	if not h.cast_manual and skill.targeting == SkillData.Targeting.DIRECTION and skill.quick_aim == SkillData.QuickAim.AT_ENEMY:
		# Quick-cast direction skills track the enemy during the cast, without leading.
		h.cast_aim = _dir_or(foe.pos - h.pos, h.facing) * skill.range_px
		_face(h, h.cast_aim)
	h.cast_ticks_left -= 1
	if h.cast_ticks_left <= 0:
		_fire_skill(h)


func _quick_aim(h: HeroState, skill: SkillData, move: Vector2, foe: HeroState) -> Vector2:
	var to_foe := foe.pos - h.pos
	if skill.quick_aim == SkillData.QuickAim.AT_ENEMY:
		if skill.targeting == SkillData.Targeting.POINT:
			return to_foe.limit_length(skill.range_px)
		return _dir_or(to_foe, h.facing) * skill.range_px
	if skill.quick_aim == SkillData.QuickAim.AWAY_OR_JOYSTICK:
		if move.length() > SimConst.MOVE_DEADZONE:
			return move.normalized() * skill.range_px
		return _dir_or(-to_foe, -h.facing) * skill.range_px
	return Vector2.ZERO


func _fire_skill(h: HeroState) -> void:
	var slot := h.cast_slot
	var skill: SkillData = h.data.skills[slot]
	var aim := h.cast_aim
	h.skill_cds.start(slot, skill.cooldown_ticks())
	h.gcd_ticks = SimConst.GCD_TICKS
	_face(h, aim)
	var ev := emit_event(SimEvent.Kind.SKILL_FIRED, h.index, -1, slot)
	if ev != null:
		ev.pos = h.pos + aim
	h.clear_cast()
	SkillExecutor.fire(self, h, skill, aim)


# --- Forced movement ------------------------------------------------------------

## Advances every dash and knockback together: all of them move first, then all of their
## hits resolve against where the other hero stood at the start of the tick. Two heroes
## charging into each other therefore trade, instead of the one that happened to move
## second landing the only hit.
func _advance_movers() -> void:
	var starts: Array[Vector2] = []
	var blocked: Array[bool] = []
	starts.resize(state.heroes.size())
	blocked.resize(state.heroes.size())
	for h in state.heroes:
		starts[h.index] = h.pos
		blocked[h.index] = false
		if not h.mover.active or not h.alive:
			continue
		var m := h.mover
		var step := minf(m.speed_px_s / SimConst.TICK_RATE, m.remaining_px)
		var wanted := h.pos + m.direction * step
		var allowed := geometry.constrain_circle(wanted, SimConst.BODY_RADIUS)
		# Stopped short by a wall or pillar: end the mover here.
		blocked[h.index] = allowed.distance_to(wanted) > 0.5
		h.pos = allowed
		m.remaining_px -= step

	# Detect every hit before applying any of them. Applying as we go would let the first
	# charge stun its target and cancel the dash that was about to hit back.
	var landed: Array[Dictionary] = []
	for h in state.heroes:
		var m := h.mover
		if not m.active or m.payload.is_empty() or not h.alive:
			continue
		var foe := state.enemy_of(h.index)
		if not foe.alive or m.hit_indices.has(foe.index):
			continue
		var reach := m.half_width + SimConst.HURT_RADIUS
		if ArenaGeometry.point_segment_distance(starts[foe.index], starts[h.index], h.pos) <= reach:
			m.hit_indices.append(foe.index)
			if m.stop_on_hit:
				m.remaining_px = 0.0
			landed.append({"source": h, "target": foe, "payload": m.payload, "at": starts[foe.index]})
	for hit in landed:
		queue_hit(hit["source"], hit["target"], hit["payload"], hit["at"])

	for h in state.heroes:
		# A payload effect (a stun landing on us) may already have cleared the mover.
		if h.mover.active and (blocked[h.index] or h.mover.remaining_px <= 0.01):
			h.mover.clear()


# --- Normal attack and movement -------------------------------------------------

func _update_attack(h: HeroState, cmd: HeroCommand, foe: HeroState) -> void:
	if h.windup_ticks > 0:
		_face(h, foe.pos - h.pos)
		h.windup_ticks -= 1
		if h.windup_ticks == 0:
			_resolve_attack(h, foe)
		return
	if not (cmd.attack_held or cmd.attack_pressed) or not foe.alive:
		return
	if _can_attack_target(h, foe):
		if h.attack_cd == 0:
			h.attack_cd = h.data.attack_interval_ticks()
			h.windup_ticks = h.data.attack_windup_ticks()
			_face(h, foe.pos - h.pos)
			emit_event(SimEvent.Kind.ATTACK_STARTED, h.index, foe.index)
			if h.windup_ticks == 0:
				_resolve_attack(h, foe)
	elif cmd.attack_pressed and not cmd.attack_held:
		emit_event(SimEvent.Kind.ATTACK_DENIED_RANGE, h.index, foe.index)


## Lands the melee hit, or launches the homing arrow, at the end of the windup.
func _resolve_attack(h: HeroState, foe: HeroState) -> void:
	if not foe.alive:
		return
	if h.data.attack_type == HeroData.AttackType.MELEE:
		if h.pos.distance_to(foe.pos) <= h.data.attack_range + SimConst.MELEE_TOLERANCE_PX:
			queue_hit(h, foe, h.attack_payload, foe.pos)
		return
	spawn_projectile(h, h.attack_projectile, _dir_or(foe.pos - h.pos, h.facing))


func _can_attack_target(h: HeroState, foe: HeroState) -> bool:
	var reach := h.data.attack_range
	if h.data.attack_type == HeroData.AttackType.MELEE:
		reach += SimConst.MELEE_TOLERANCE_PX
	if h.pos.distance_to(foe.pos) > reach:
		return false
	# Ranged heroes do not start an attack into a pillar.
	if h.data.attack_type == HeroData.AttackType.PROJECTILE:
		return not geometry.segment_blocked_by_pillar(h.pos, foe.pos, h.data.projectile_radius)
	return true


func _desired_walk(h: HeroState, cmd: HeroCommand, foe: HeroState) -> Vector2:
	if cmd.move.length() > SimConst.MOVE_DEADZONE:
		return cmd.move.normalized()
	if cmd.attack_held and foe.alive and not _can_attack_target(h, foe):
		# Attack-move: holding attack with an idle stick walks toward the target.
		return _dir_or(foe.pos - h.pos, Vector2.ZERO)
	return Vector2.ZERO


## Queues a hit to be applied once every hero has acted this tick, so two blows landing
## on the same tick always trade: neither can cancel the other by landing first.
func queue_hit(source: HeroState, target: HeroState, effects: Array[EffectData], at: Vector2) -> void:
	if effects.is_empty() or target == null or not target.alive:
		return
	_pending_hits.append({"source": source, "target": target, "effects": effects, "at": at})


func _flush_hits() -> void:
	if _pending_hits.is_empty():
		return
	var hits := _pending_hits
	_pending_hits = []
	for hit in hits:
		EffectApplier.apply_all(self, hit["source"], hit["target"], hit["effects"], hit["at"])


## Phase 2: every hero walks from the same start-of-tick snapshot.
func _apply_walk(h: HeroState, dir: Vector2) -> void:
	# A hit flushed a moment ago may have stunned or killed this hero.
	if dir == Vector2.ZERO or not h.alive or h.is_stunned() or h.mover.active:
		return
	var speed := h.data.move_speed * h.speed_multiplier()
	if h.windup_ticks > 0:
		speed *= 0.5
	h.pos += dir * speed / SimConst.TICK_RATE
	if h.windup_ticks == 0:
		_face(h, dir)


func _separate_heroes() -> void:
	if state.heroes.size() < 2:
		return
	var a := state.heroes[0]
	var b := state.heroes[1]
	if a.mover.pass_through and a.mover.active:
		return
	if b.mover.pass_through and b.mover.active:
		return
	var min_dist := SimConst.BODY_RADIUS * 2.0
	var delta := b.pos - a.pos
	var dist := delta.length()
	if dist >= min_dist:
		return
	var dir: Vector2 = delta / dist if dist > 0.001 else Vector2.RIGHT
	var push := (min_dist - dist) * 0.5
	a.pos -= dir * push
	b.pos += dir * push


# --- Projectiles ----------------------------------------------------------------

func spawn_projectile(owner: HeroState, effect: ProjectileEffect, dir: Vector2) -> void:
	_next_projectile_id += 1
	state.projectiles.append(ProjectileState.create(_next_projectile_id, owner.index, owner.pos, dir, effect))


func _advance_projectiles() -> void:
	var survivors: Array[ProjectileState] = []
	for p in state.projectiles:
		if _advance_projectile(p):
			survivors.append(p)
	state.projectiles = survivors


## Returns false when the projectile is spent: it hit someone, a wall or its max range.
func _advance_projectile(p: ProjectileState) -> bool:
	var target := state.heroes[1 - p.owner_index]
	if p.homing and target.alive:
		p.direction = _dir_or(target.pos - p.pos, p.direction)
	var step := minf(p.speed_px_s / SimConst.TICK_RATE, p.remaining_px)
	var from := p.pos
	p.pos = from + p.direction * step
	p.remaining_px -= step

	if target.alive and ArenaGeometry.point_segment_distance(target.pos, from, p.pos) <= p.radius_px + SimConst.HURT_RADIUS:
		queue_hit(state.heroes[p.owner_index], target, p.payload, target.pos)
		return false
	if not geometry.is_inside(p.pos, p.radius_px):
		return false
	return p.remaining_px > 0.01


# --- Timers ---------------------------------------------------------------------

func _tick_timers(h: HeroState) -> void:
	h.skill_cds.tick()
	if h.gcd_ticks > 0:
		h.gcd_ticks -= 1
	if h.attack_cd > 0:
		h.attack_cd -= 1
	if h.buffered_ticks > 0:
		h.buffered_ticks -= 1
		if h.buffered_ticks == 0:
			h.clear_buffer()
	if h.slow_ticks > 0:
		h.slow_ticks -= 1
		if h.slow_ticks == 0:
			h.slow_pct = 0.0
	if h.stun_ticks > 0:
		h.stun_ticks -= 1


# --- Helpers --------------------------------------------------------------------

func _face(h: HeroState, v: Vector2) -> void:
	if v.length_squared() > 0.0001:
		h.facing = v.normalized()


static func _dir_or(v: Vector2, fallback: Vector2) -> Vector2:
	return v.normalized() if v.length_squared() > 0.0001 else fallback


func emit_event(kind: SimEvent.Kind, source: int, target: int = -1, slot: int = -1, amount: int = 0) -> SimEvent:
	if not _emit_events:
		return null
	var ev := SimEvent.create(kind, state.tick, source, target, slot, amount)
	state.events.append(ev)
	return ev
