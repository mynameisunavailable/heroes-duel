class_name EffectApplier
extends RefCounted
## Applies instant effect primitives to a target. Carrier effects (dash, projectile,
## area over time) are not handled here: SkillExecutor turns those into movers,
## projectiles and areas whose payloads come back through this class on hit.


static func apply_all(sim: CombatSim, source: HeroState, target: HeroState, effects: Array[EffectData], at: Vector2) -> void:
	for effect in effects:
		apply(sim, source, target, effect, at)


static func apply(sim: CombatSim, source: HeroState, target: HeroState, effect: EffectData, at: Vector2) -> void:
	if effect == null or target == null:
		return
	if effect is DamageEffect:
		DamageResolver.apply(sim, source, target, (effect as DamageEffect).amount, at)
	elif effect is SlowEffect:
		var slow := effect as SlowEffect
		StatusRules.apply_slow(sim, target, slow.pct, slow.duration_s)
	elif effect is StunEffect:
		StatusRules.apply_stun(sim, target, (effect as StunEffect).duration_s)
	elif effect is KnockbackEffect:
		var kb := effect as KnockbackEffect
		StatusRules.apply_knockback(sim, source, target, kb.distance_px, kb.travel_s)
	# Dash, Projectile and AreaOverTime are carriers; SkillExecutor handles them.
