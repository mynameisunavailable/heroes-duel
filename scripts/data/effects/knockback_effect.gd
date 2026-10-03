class_name KnockbackEffect
extends EffectData
## Pushes the target directly away from the caster. Walls and pillars stop the push, and
## it interrupts whatever the target was doing.

@export_range(0.0, 200.0, 1.0, "suffix:px") var distance_px: float = 0.0
@export_range(0.01, 0.2, 0.01, "suffix:s") var travel_s: float = 0.16


func describe() -> String:
	return "Knock back %d px" % roundi(distance_px)
