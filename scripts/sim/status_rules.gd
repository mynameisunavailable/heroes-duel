class_name StatusRules
extends RefCounted
## Crowd-control rules in one place: stuns, slows and knockbacks, including what they
## interrupt. Stun-lock is prevented by the roster itself (at most one stun per hero, on
## a 10 s or longer cooldown), so there is no immunity window in v1.


static func apply_stun(sim: CombatSim, target: HeroState, duration_s: float) -> void:
	if not target.alive:
		return
	target.stun_ticks = maxi(target.stun_ticks, SimConst.to_ticks(duration_s))
	_interrupt(sim, target)
	sim.emit_event(SimEvent.Kind.STATUS_APPLIED, -1, target.index, -1, target.stun_ticks)


## The strongest active slow wins; slows never stack. A weaker slow cannot refresh a
## stronger one, and walking speed never drops below SimConst.MIN_SPEED_FACTOR.
static func apply_slow(sim: CombatSim, target: HeroState, pct: float, duration_s: float) -> void:
	if not target.alive or pct <= 0.0:
		return
	var ticks := SimConst.to_ticks(duration_s)
	var active := target.slow_ticks > 0
	if active and pct < target.slow_pct:
		return
	# An equally strong slow only refreshes the duration; a stronger one replaces both.
	target.slow_ticks = maxi(target.slow_ticks, ticks) if active and is_equal_approx(pct, target.slow_pct) else ticks
	target.slow_pct = pct
	sim.emit_event(SimEvent.Kind.STATUS_APPLIED, -1, target.index, -1, ticks)


static func apply_knockback(sim: CombatSim, source: HeroState, target: HeroState, distance_px: float, travel_s: float) -> void:
	if not target.alive or distance_px <= 0.0:
		return
	var away := target.pos - source.pos
	var dir := away.normalized() if away.length_squared() > 0.0001 else source.facing
	_interrupt(sim, target)
	target.mover.start_knockback(distance_px, travel_s, dir)
	sim.emit_event(SimEvent.Kind.STATUS_APPLIED, source.index, target.index)


## Cancels whatever the target was doing. An interrupted cast goes on a fixed cooldown
## rather than being refunded, so interrupts are worth landing.
static func _interrupt(sim: CombatSim, target: HeroState) -> void:
	if target.is_casting():
		target.skill_cds.start(target.cast_slot, SimConst.INTERRUPT_CD_TICKS)
		sim.emit_event(SimEvent.Kind.SKILL_DENIED, target.index, -1, target.cast_slot)
		target.clear_cast()
	target.mover.clear()
	target.windup_ticks = 0
	target.clear_buffer()
