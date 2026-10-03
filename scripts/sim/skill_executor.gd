class_name SkillExecutor
extends RefCounted
## Turns a fired skill into simulation state, based on its targeting mode:
## DIRECTION spawns a projectile or starts a dash along the aim; AROUND_SELF applies its
## payload to everyone inside a radius; POINT applies it around a chosen spot.
## Instant effects go through EffectApplier; carriers become movers and projectiles.


static func fire(sim: CombatSim, caster: HeroState, skill: SkillData, aim: Vector2) -> void:
	var dir := aim.normalized() if aim.length_squared() > 0.0001 else caster.facing
	for effect in skill.effects:
		if effect is ProjectileEffect:
			sim.spawn_projectile(caster, effect as ProjectileEffect, dir)
		elif effect is DashEffect:
			caster.mover.start_dash(effect as DashEffect, dir)
		elif effect is AreaOverTimeEffect:
			# v1.1 (Pyromancer's Meteor, Rogue's Poison Cloud).
			push_warning("AreaOverTimeEffect is not implemented yet: %s" % skill.id)
		else:
			_apply_instant(sim, caster, skill, effect, aim)


## Instant effects need a shape, since they have no carrier to collide. AROUND_SELF hits
## around the caster, POINT around the aimed spot, and a bare DIRECTION effect hits the
## target the caster is facing within range.
static func _apply_instant(sim: CombatSim, caster: HeroState, skill: SkillData, effect: EffectData, aim: Vector2) -> void:
	var centre := caster.pos
	var radius := skill.radius_or_width_px
	match skill.targeting:
		SkillData.Targeting.POINT:
			centre = caster.pos + aim.limit_length(skill.range_px)
		SkillData.Targeting.DIRECTION:
			centre = caster.pos + aim.limit_length(skill.range_px)
			radius = skill.radius_or_width_px * 0.5
		_:
			centre = caster.pos
	var single: Array[EffectData] = [effect]
	for target in sim.state.heroes:
		if target.index == caster.index or not target.alive:
			continue
		if target.pos.distance_to(centre) <= radius + SimConst.HURT_RADIUS:
			sim.queue_hit(caster, target, single, target.pos)
