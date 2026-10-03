class_name StunEffect
extends EffectData
## The target cannot move, attack or cast. Cancels a cast in progress.

@export_range(0.0, 1.0, 0.05, "suffix:s") var duration_s: float = 0.0


func describe() -> String:
	return "Stun %.2f s" % duration_s
