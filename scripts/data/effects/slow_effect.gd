class_name SlowEffect
extends EffectData
## Multiplies walking speed by (1 - pct). The strongest active slow wins; slows never stack.

@export_range(0.0, 0.4, 0.01) var pct: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var duration_s: float = 0.0


func describe() -> String:
	return "Slow %d%% for %.2f s" % [roundi(pct * 100.0), duration_s]
