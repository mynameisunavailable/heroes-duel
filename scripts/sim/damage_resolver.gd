class_name DamageResolver
extends RefCounted
## The single path to HP loss. Everything that deals damage goes through here, so the
## overtime multiplier, damage tracking and KO detection exist in exactly one place.


static func apply(sim: CombatSim, source: HeroState, target: HeroState, amount: int, at: Vector2) -> void:
	if not target.alive or amount <= 0:
		return
	var dealt := amount
	if sim.state.is_overtime():
		dealt = roundi(amount * SimConst.OVERTIME_DAMAGE_MULT)
	dealt = mini(dealt, target.hp)
	target.hp -= dealt
	var source_index := -1
	if source != null:
		source.damage_dealt += dealt
		source_index = source.index

	var hit := sim.emit_event(SimEvent.Kind.DAMAGE, source_index, target.index, -1, dealt)
	if hit != null:
		hit.pos = at
	if target.hp == 0:
		target.alive = false
		target.clear_cast()
		target.clear_buffer()
		target.mover.clear()
		var ko := sim.emit_event(SimEvent.Kind.KO, source_index, target.index)
		if ko != null:
			ko.pos = target.pos
